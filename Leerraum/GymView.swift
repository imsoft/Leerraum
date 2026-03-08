import SwiftUI
import SwiftData
import Combine
import Charts
import OSLog

private struct RoutineSessionState: Equatable {
    var isStarted = false
    var currentExerciseID: UUID?
    var currentSetNumber = 1
    var completedSetsByExercise: [UUID: Int] = [:]
    var completedExerciseIDs: Set<UUID> = []
    var restRemainingSeconds = 0
    var restingExerciseID: UUID?
    var restingSetNumber: Int?
}

private struct GymHistoryPoint: Identifiable {
    let id: UUID
    let date: Date
    let weightKg: Double
    let reps: Int
}

private struct GymPRSummary {
    let bestWeightKg: Double
    let bestWeightDate: Date
    let bestVolumeKg: Double
    let bestVolumeDate: Date
}

private struct GymRoutineSheetTarget: Identifiable {
    let id: UUID
}

private struct GymExerciseSheetTarget: Identifiable {
    let routineID: UUID
    let exerciseID: UUID

    var id: String { "\(routineID.uuidString)|\(exerciseID.uuidString)" }
}

struct GymView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymRoutine.createdAt, order: .reverse) private var routines: [GymRoutine]
    @Query(sort: \GymSetRecord.performedAt, order: .reverse) private var setRecords: [GymSetRecord]

    @State private var showingAddRoutineSheet = false
    @State private var addExerciseTarget: GymRoutineSheetTarget?
    @State private var editRoutineTarget: GymRoutineSheetTarget?
    @State private var editExerciseTarget: GymExerciseSheetTarget?
    @State private var routineSessions: [UUID: RoutineSessionState] = [:]
    @State private var setWeightDraftByExerciseID: [UUID: Double] = [:]
    @State private var selectedHistoryExerciseName = ""
    @State private var historyExerciseNames: [String] = []
    @State private var historyRecordsByName: [String: [GymSetRecord]] = [:]
    @State private var restTimerConnection: Cancellable?

    private let restTimer = Timer.publish(every: 1, on: .main, in: .common)

    private var historyRefreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(routines.count)
        hasher.combine(setRecords.count)
        hasher.combine(routines.first?.id)
        hasher.combine(setRecords.first?.id)
        hasher.combine(setRecords.first?.performedAt.timeIntervalSinceReferenceDate)
        hasher.combine(setRecords.last?.id)
        return hasher.finalize()
    }

    private var totalExercises: Int {
        routines
            .map { $0.exercises.count }
            .reduce(0, +)
    }

    private var totalVolumeKg: Double {
        routines
            .flatMap(\.exercises)
            .reduce(0) { partial, exercise in
                partial + exercise.trainingVolumeKg
            }
    }

    private var averageRestSeconds: Int {
        let allExercises = routines.flatMap(\.exercises)
        guard !allExercises.isEmpty else { return 0 }

        let sum = allExercises.map(\.restSeconds).reduce(0, +)
        return Int(Double(sum) / Double(allExercises.count))
    }

    private var availableHistoryExerciseNames: [String] {
        historyExerciseNames
    }

    private var activeHistoryExerciseName: String {
        if availableHistoryExerciseNames.contains(selectedHistoryExerciseName) {
            return selectedHistoryExerciseName
        }
        return availableHistoryExerciseNames.first ?? ""
    }

    private var hasActiveRestSession: Bool {
        routineSessions.contains { _, session in
            session.isStarted && session.restRemainingSeconds > 0
        }
    }

    private var historyRecordsForSelectedExercise: [GymSetRecord] {
        guard !activeHistoryExerciseName.isEmpty else { return [] }
        return historyRecordsByName[activeHistoryExerciseName] ?? []
    }

    private var historyPointsForSelectedExercise: [GymHistoryPoint] {
        historyRecordsForSelectedExercise.map { record in
            GymHistoryPoint(
                id: record.id,
                date: record.performedAt,
                weightKg: record.weightKg,
                reps: record.reps
            )
        }
    }

    private var prSummaryForSelectedExercise: GymPRSummary? {
        guard !historyRecordsForSelectedExercise.isEmpty else { return nil }

        guard
            let bestWeight = historyRecordsForSelectedExercise.max(by: { lhs, rhs in
                if lhs.weightKg == rhs.weightKg {
                    return lhs.performedAt < rhs.performedAt
                }
                return lhs.weightKg < rhs.weightKg
            }),
            let bestVolume = historyRecordsForSelectedExercise.max(by: { lhs, rhs in
                if lhs.volumeKg == rhs.volumeKg {
                    return lhs.performedAt < rhs.performedAt
                }
                return lhs.volumeKg < rhs.volumeKg
            })
        else {
            return nil
        }

        return GymPRSummary(
            bestWeightKg: bestWeight.weightKg,
            bestWeightDate: bestWeight.performedAt,
            bestVolumeKg: bestVolume.volumeKg,
            bestVolumeDate: bestVolume.performedAt
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GymBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        GymHeaderCard(
                            routinesCount: routines.count,
                            exercisesCount: totalExercises,
                            totalVolumeKg: totalVolumeKg,
                            averageRestSeconds: averageRestSeconds
                        )

                        GymHistoryOverviewCard(
                            exerciseOptions: availableHistoryExerciseNames,
                            selectedExerciseName: activeHistoryExerciseName,
                            historyPoints: historyPointsForSelectedExercise,
                            prSummary: prSummaryForSelectedExercise,
                            onSelectExercise: { selectedHistoryExerciseName = $0 }
                        )

                        FeatureSectionHeader(title: "Rutinas") {
                            Button {
                                showingAddRoutineSheet = true
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Gym.c600)
                        }

                        if routines.isEmpty {
                            GymEmptyStateCard {
                                showingAddRoutineSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(routines, id: \.id) { routine in
                                    let ordered = orderedExercises(for: routine)
                                    GymRoutineCard(
                                        routine: routine,
                                        orderedExercises: ordered,
                                        session: routineSession(for: routine, orderedExercises: ordered),
                                        setWeightForExercise: { exercise in
                                            setWeightDraft(for: exercise)
                                        },
                                        onEditRoutine: {
                                            editRoutineTarget = GymRoutineSheetTarget(id: routine.id)
                                        },
                                        onAddExercise: {
                                            addExerciseTarget = GymRoutineSheetTarget(id: routine.id)
                                        },
                                        onStartRoutine: {
                                            startRoutine(routine)
                                        },
                                        onResetRoutine: {
                                            resetRoutine(routine)
                                        },
                                        onDecreaseSetWeight: { exercise in
                                            adjustSetWeight(for: exercise, delta: -0.5)
                                        },
                                        onIncreaseSetWeight: { exercise in
                                            adjustSetWeight(for: exercise, delta: 0.5)
                                        },
                                        onCompleteExercise: { exercise in
                                            completeExercise(
                                                exercise,
                                                in: routine,
                                                setWeightKg: setWeightDraft(for: exercise)
                                            )
                                        },
                                        onSelectExercise: { exercise in
                                            editExerciseTarget = GymExerciseSheetTarget(
                                                routineID: routine.id,
                                                exerciseID: exercise.id
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddRoutineSheet) {
                AddGymRoutineView { name, note, weekday in
                    createRoutine(name: name, note: note, weekday: weekday)
                }
            }
            .sheet(item: $addExerciseTarget) { target in
                if let routine = routines.first(where: { $0.id == target.id }) {
                    AddGymExerciseView(routineName: routine.name) { name, sets, reps, weightKg, restSeconds in
                        createExercise(
                            for: routine,
                            name: name,
                            sets: sets,
                            reps: reps,
                            weightKg: weightKg,
                            restSeconds: restSeconds
                        )
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Rutina no disponible",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Esta rutina ya no existe.")
                        )
                    }
                }
            }
            .sheet(item: $editExerciseTarget) { target in
                if let routine = routines.first(where: { $0.id == target.routineID }),
                   let exercise = routine.exercises.first(where: { $0.id == target.exerciseID }) {
                    AddGymExerciseView(
                        routineName: routine.name,
                        initialExercise: exercise
                    ) { name, sets, reps, weightKg, restSeconds in
                        updateExercise(
                            exercise,
                            name: name,
                            sets: sets,
                            reps: reps,
                            weightKg: weightKg,
                            restSeconds: restSeconds
                        )
                    } onDelete: {
                        delete(exercise)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Ejercicio no disponible",
                            systemImage: "dumbbell.fill",
                            description: Text("Este ejercicio ya no existe.")
                        )
                    }
                }
            }
            .sheet(item: $editRoutineTarget) { target in
                if let routine = routines.first(where: { $0.id == target.id }) {
                    EditGymRoutineView(
                        routine: routine
                    ) { name, note, weekday in
                        updateRoutine(routine, name: name, note: note, weekday: weekday)
                    } onDelete: {
                        delete(routine)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Rutina no disponible",
                            systemImage: "list.bullet.rectangle.portrait",
                            description: Text("Esta rutina ya no existe.")
                        )
                    }
                }
            }
            .animation(.snappy(duration: 0.3), value: routines.count)
            .onAppear {
                AppNotificationService.shared.requestAuthorizationIfNeeded()
                rebuildHistoryIndex()
                ensureSelectedHistoryExerciseName()
                updateRestTimerConnection()
            }
            .onDisappear {
                restTimerConnection?.cancel()
                restTimerConnection = nil
            }
            .onChange(of: historyRefreshSignature) { _, _ in
                rebuildHistoryIndex()
                ensureSelectedHistoryExerciseName()
            }
            .onChange(of: hasActiveRestSession) { _, _ in
                updateRestTimerConnection()
            }
            .onReceive(restTimer) { _ in
                tickRestCountdowns()
            }
        }
    }

    private func createRoutine(name: String, note: String, weekday: RoutineWeekday) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.insert(
                GymRoutine(
                    name: trimmedName,
                    note: trimmedNote,
                    scheduledWeekday: weekday
                )
            )
        }
    }

    private func createExercise(
        for routine: GymRoutine,
        name: String,
        sets: Int,
        reps: Int,
        weightKg: Double,
        restSeconds: Int
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let nextOrder = (routine.exercises.map(\.order).max() ?? -1) + 1
        let exercise = GymExercise(
            name: trimmedName,
            sets: sets,
            reps: reps,
            weightKg: weightKg,
            restSeconds: restSeconds,
            order: nextOrder,
            routine: routine
        )

        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.insert(exercise)
        }
        setWeightDraftByExerciseID[exercise.id] = max(exercise.weightKg, 0)
    }

    private func delete(_ routine: GymRoutine) {
        let exerciseIDs = routine.exercises.map(\.id)
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(routine)
        }
        exerciseIDs.forEach { setWeightDraftByExerciseID[$0] = nil }
        routineSessions[routine.id] = nil
    }

    private func delete(_ exercise: GymExercise) {
        if let routineID = exercise.routine?.id, var session = routineSessions[routineID] {
            session.completedExerciseIDs.remove(exercise.id)
            session.completedSetsByExercise[exercise.id] = nil
            if session.currentExerciseID == exercise.id {
                session.currentExerciseID = nil
                session.currentSetNumber = 1
            }
            if session.restingExerciseID == exercise.id {
                session.restingExerciseID = nil
                session.restingSetNumber = nil
                session.restRemainingSeconds = 0
            }
            routineSessions[routineID] = session
        }
        setWeightDraftByExerciseID[exercise.id] = nil

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(exercise)
        }
    }

    private func updateExercise(
        _ exercise: GymExercise,
        name: String,
        sets: Int,
        reps: Int,
        weightKg: Double,
        restSeconds: Int
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            exercise.name = trimmedName
            exercise.sets = sets
            exercise.reps = reps
            exercise.weightKg = max(weightKg, 0)
            exercise.restSeconds = restSeconds
        }
        setWeightDraftByExerciseID[exercise.id] = max(weightKg, 0)
    }

    private func setWeightDraft(for exercise: GymExercise) -> Double {
        max(setWeightDraftByExerciseID[exercise.id] ?? exercise.weightKg, 0)
    }

    private func adjustSetWeight(for exercise: GymExercise, delta: Double) {
        let base = setWeightDraft(for: exercise)
        let updated = min(max(base + delta, 0), 500)
        setWeightDraftByExerciseID[exercise.id] = updated
    }

    private func primeSetWeightDrafts(for exercises: [GymExercise]) {
        for exercise in exercises {
            if setWeightDraftByExerciseID[exercise.id] == nil {
                setWeightDraftByExerciseID[exercise.id] = max(exercise.weightKg, 0)
            }
        }
    }

    private func updateRoutine(_ routine: GymRoutine, name: String, note: String, weekday: RoutineWeekday) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) {
            routine.name = trimmedName
            routine.note = trimmedNote
            routine.scheduledWeekday = weekday
        }
    }

    private func normalizedExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rebuildHistoryIndex() {
        let interval = Observability.gymSignposter.beginInterval("gym.history.rebuild")
        defer { Observability.gymSignposter.endInterval("gym.history.rebuild", interval) }
        let currentExerciseNames = routines
            .flatMap(\.exercises)
            .map(\.name)
            .map(normalizedExerciseName)
            .filter { !$0.isEmpty }

        let groupedHistory = Dictionary(grouping: setRecords) { record in
            normalizedExerciseName(record.exerciseName)
        }
        .filter { !$0.key.isEmpty }
        .mapValues { records in
            records.sorted { lhs, rhs in
                if lhs.performedAt == rhs.performedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.performedAt < rhs.performedAt
            }
        }

        let names = Set(currentExerciseNames + Array(groupedHistory.keys))
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }

        historyExerciseNames = names
        historyRecordsByName = groupedHistory
        Observability.debug(
            Observability.gymLogger,
            "History index rebuilt. names: \(names.count), records: \(setRecords.count)"
        )
    }

    private func ensureSelectedHistoryExerciseName() {
        guard !availableHistoryExerciseNames.isEmpty else {
            selectedHistoryExerciseName = ""
            return
        }

        if !availableHistoryExerciseNames.contains(selectedHistoryExerciseName) {
            selectedHistoryExerciseName = availableHistoryExerciseNames.first ?? ""
        }
    }

    private func recordCompletedSet(
        exercise: GymExercise,
        routine: GymRoutine,
        setNumber: Int,
        weightKg: Double
    ) {
        let record = GymSetRecord(
            exerciseID: exercise.id,
            exerciseName: normalizedExerciseName(exercise.name),
            routineName: routine.name.trimmingCharacters(in: .whitespacesAndNewlines),
            performedAt: .now,
            setNumber: max(setNumber, 1),
            reps: max(exercise.reps, 0),
            weightKg: max(weightKg, 0)
        )
        modelContext.insert(record)
    }

    private func orderedExercises(for routine: GymRoutine) -> [GymExercise] {
        routine.exercises.sorted {
            if $0.order == $1.order {
                return $0.createdAt < $1.createdAt
            }
            return $0.order < $1.order
        }
    }

    private func routineSession(
        for routine: GymRoutine,
        orderedExercises: [GymExercise]? = nil
    ) -> RoutineSessionState {
        var session = routineSessions[routine.id] ?? RoutineSessionState()
        let ordered = orderedExercises ?? self.orderedExercises(for: routine)
        let validIDs = Set(ordered.map(\.id))
        let exerciseByID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })

        session.completedSetsByExercise = session.completedSetsByExercise
            .filter { validIDs.contains($0.key) }
            .reduce(into: [:]) { partial, entry in
                if let exercise = exerciseByID[entry.key] {
                    partial[entry.key] = min(max(entry.value, 0), exercise.sets)
                }
            }

        session.completedExerciseIDs = Set(
            ordered
                .filter { (session.completedSetsByExercise[$0.id] ?? 0) >= $0.sets }
                .map(\.id)
        )

        if let currentID = session.currentExerciseID, !validIDs.contains(currentID) {
            session.currentExerciseID = nil
            session.currentSetNumber = 1
        }
        if let restingID = session.restingExerciseID, !validIDs.contains(restingID) {
            session.restingExerciseID = nil
            session.restingSetNumber = nil
            session.restRemainingSeconds = 0
        }

        if !session.isStarted {
            session.currentExerciseID = ordered.first?.id
            session.currentSetNumber = 1
            session.completedSetsByExercise = [:]
            session.completedExerciseIDs = []
            session.restRemainingSeconds = 0
            session.restingExerciseID = nil
            session.restingSetNumber = nil
        } else {
            if let currentID = session.currentExerciseID, let currentExercise = exerciseByID[currentID] {
                let completedSets = session.completedSetsByExercise[currentID] ?? 0
                if completedSets >= currentExercise.sets {
                    session.currentExerciseID = nil
                } else {
                    session.currentSetNumber = max(session.currentSetNumber, completedSets + 1)
                    session.currentSetNumber = min(session.currentSetNumber, currentExercise.sets)
                }
            }

            if session.restRemainingSeconds <= 0 {
                session.restRemainingSeconds = 0
                if session.currentExerciseID == nil, let restingID = session.restingExerciseID {
                    session.currentExerciseID = restingID
                    session.currentSetNumber = max(session.restingSetNumber ?? 1, 1)
                    session.restingExerciseID = nil
                    session.restingSetNumber = nil
                }
            }

            if session.currentExerciseID == nil && session.restRemainingSeconds == 0 {
                if let nextPending = ordered.first(where: { (session.completedSetsByExercise[$0.id] ?? 0) < $0.sets }) {
                    let completedSets = session.completedSetsByExercise[nextPending.id] ?? 0
                    session.currentExerciseID = nextPending.id
                    session.currentSetNumber = min(completedSets + 1, nextPending.sets)
                }
            }
        }

        return session
    }

    private func startRoutine(_ routine: GymRoutine) {
        let ordered = orderedExercises(for: routine)
        guard !ordered.isEmpty else { return }
        primeSetWeightDrafts(for: ordered)

        routineSessions[routine.id] = RoutineSessionState(
            isStarted: true,
            currentExerciseID: ordered.first?.id,
            currentSetNumber: 1,
            completedSetsByExercise: [:],
            completedExerciseIDs: [],
            restRemainingSeconds: 0,
            restingExerciseID: nil,
            restingSetNumber: nil
        )
    }

    private func resetRoutine(_ routine: GymRoutine) {
        routineSessions[routine.id] = RoutineSessionState()
    }

    private func completeExercise(
        _ exercise: GymExercise,
        in routine: GymRoutine,
        setWeightKg: Double
    ) {
        var session = routineSession(for: routine)
        guard session.isStarted else { return }
        guard session.restRemainingSeconds == 0 else { return }
        guard session.currentExerciseID == exercise.id else { return }

        let ordered = orderedExercises(for: routine)
        let completedSets = session.completedSetsByExercise[exercise.id] ?? 0
        let nextCompletedSets = min(completedSets + 1, exercise.sets)
        session.completedSetsByExercise[exercise.id] = nextCompletedSets

        recordCompletedSet(
            exercise: exercise,
            routine: routine,
            setNumber: nextCompletedSets,
            weightKg: max(setWeightKg, 0)
        )

        if nextCompletedSets >= exercise.sets {
            session.completedExerciseIDs.insert(exercise.id)
        }

        guard let index = ordered.firstIndex(where: { $0.id == exercise.id }) else {
            routineSessions[routine.id] = session
            return
        }

        let isExerciseCompleted = nextCompletedSets >= exercise.sets
        let rest = max(exercise.restSeconds, 0)

        if !isExerciseCompleted {
            let nextSet = min(nextCompletedSets + 1, exercise.sets)

            if rest > 0 {
                session.currentExerciseID = nil
                session.restingExerciseID = exercise.id
                session.restingSetNumber = nextSet
                session.restRemainingSeconds = rest
            } else {
                session.currentExerciseID = exercise.id
                session.currentSetNumber = nextSet
                session.restingExerciseID = nil
                session.restingSetNumber = nil
                session.restRemainingSeconds = 0
            }
        } else {
            let hasNextExercise = index < ordered.count - 1
            if hasNextExercise {
                let nextExercise = ordered[index + 1]
                if rest > 0 {
                    session.currentExerciseID = nil
                    session.restingExerciseID = nextExercise.id
                    session.restingSetNumber = 1
                    session.restRemainingSeconds = rest
                } else {
                    session.currentExerciseID = nextExercise.id
                    session.currentSetNumber = 1
                    session.restingExerciseID = nil
                    session.restingSetNumber = nil
                    session.restRemainingSeconds = 0
                }
            } else {
                session.currentExerciseID = nil
                session.currentSetNumber = 1
                session.restingExerciseID = nil
                session.restingSetNumber = nil
                session.restRemainingSeconds = 0
            }
        }

        routineSessions[routine.id] = session
    }

    private func tickRestCountdowns() {
        let interval = Observability.gymSignposter.beginInterval("gym.rest.tick")
        defer { Observability.gymSignposter.endInterval("gym.rest.tick", interval) }
        var updatedSessions = routineSessions
        var hasChanges = false

        for (routineID, session) in updatedSessions {
            guard session.isStarted, session.restRemainingSeconds > 0 else { continue }
            var updated = session
            updated.restRemainingSeconds -= 1

            if updated.restRemainingSeconds <= 0 {
                let nextExerciseID = updated.restingExerciseID
                let nextSetNumber = max(updated.restingSetNumber ?? 1, 1)
                updated.restRemainingSeconds = 0
                updated.currentExerciseID = updated.restingExerciseID
                updated.currentSetNumber = nextSetNumber
                updated.restingExerciseID = nil
                updated.restingSetNumber = nil

                notifyRestFinished(
                    routineID: routineID,
                    nextExerciseID: nextExerciseID,
                    nextSetNumber: nextSetNumber
                )
            }

            updatedSessions[routineID] = updated
            hasChanges = true
        }

        if hasChanges {
            routineSessions = updatedSessions
        }
    }

    private func notifyRestFinished(
        routineID: UUID,
        nextExerciseID: UUID?,
        nextSetNumber: Int
    ) {
        let routine = routines.first { $0.id == routineID }
        let routineName = routine?.name ?? "Tu rutina"
        let nextExerciseName = routine?.exercises.first { $0.id == nextExerciseID }?.name

        let body: String
        if let nextExerciseName {
            body = "Sigue con \(nextExerciseName), serie \(nextSetNumber) en \(routineName)."
        } else {
            body = "Descanso terminado en \(routineName)."
        }

        AppNotificationService.shared.notifyRestFinished(body: body)
    }

    private func updateRestTimerConnection() {
        if hasActiveRestSession {
            if restTimerConnection == nil {
                restTimerConnection = restTimer.connect()
            }
        } else {
            restTimerConnection?.cancel()
            restTimerConnection = nil
        }
    }
}

private struct GymBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .gym)
    }
}

private struct GymHeaderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let routinesCount: Int
    let exercisesCount: Int
    let totalVolumeKg: Double
    let averageRestSeconds: Int

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Gym.c900, AppPalette.Gym.c700]
        }
        return [AppPalette.Gym.c600, AppPalette.Gym.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu entrenamiento")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(routinesCount)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("rutinas")
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 8) {
                GymMetricPill(title: "Ejercicios", value: "\(exercisesCount)")
                GymMetricPill(title: "Volumen", value: "\(totalVolumeKg.formatted(.number.precision(.fractionLength(0)))) kg")
                GymMetricPill(title: "Descanso", value: "\(averageRestSeconds)s")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.13), radius: 14, x: 0, y: 8)
    }
}

private struct GymMetricPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.80 : 0.90))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            .white.opacity(colorScheme == .dark ? 0.17 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct GymHistoryOverviewCard: View {
    let exerciseOptions: [String]
    let selectedExerciseName: String
    let historyPoints: [GymHistoryPoint]
    let prSummary: GymPRSummary?
    let onSelectExercise: (String) -> Void

    private var locale: Locale {
        Locale(identifier: "es_MX")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Historial por ejercicio")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(historyPoints.count) series")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            if exerciseOptions.isEmpty {
                Text("Completa series en tus rutinas para ver progreso y PR automaticos.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                Menu {
                    ForEach(exerciseOptions, id: \.self) { option in
                        Button {
                            onSelectExercise(option)
                        } label: {
                            HStack {
                                Text(option)
                                Spacer()
                                if option == selectedExerciseName {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(AppPalette.Gym.c600)
                        Text(selectedExerciseName)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.Gym.c600)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.appField,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Gym.c600.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if let prSummary {
                    HStack(spacing: 8) {
                        GymPRPill(
                            title: "Mejor peso",
                            value: "\(prSummary.bestWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg",
                            dateText: prSummary.bestWeightDate.formatted(
                                .dateTime
                                    .locale(locale)
                                    .day()
                                    .month(.abbreviated)
                            ),
                            tint: AppPalette.Gym.c600
                        )

                        GymPRPill(
                            title: "Mejor serie",
                            value: "Vol \(prSummary.bestVolumeKg.formatted(.number.precision(.fractionLength(0...1)))) kg",
                            dateText: prSummary.bestVolumeDate.formatted(
                                .dateTime
                                    .locale(locale)
                                    .day()
                                    .month(.abbreviated)
                            ),
                            tint: AppPalette.Gym.c500
                        )
                    }
                }

                if historyPoints.count >= 2 {
                    VStack(spacing: 10) {
                        GymMiniTrendChart(
                            points: historyPoints,
                            metric: .weight,
                            locale: locale
                        )
                        GymMiniTrendChart(
                            points: historyPoints,
                            metric: .reps,
                            locale: locale
                        )
                    }
                } else if let first = historyPoints.first {
                    Text(
                        "Primera serie registrada el \(first.date.formatted(.dateTime.locale(locale).day().month(.abbreviated)))"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct GymPRPill: View {
    let title: String
    let value: String
    let dateText: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(dateText.capitalized)
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private enum GymHistoryMetric {
    case weight
    case reps

    var title: String {
        switch self {
        case .weight:
            return "Peso (kg)"
        case .reps:
            return "Repeticiones"
        }
    }

    var tint: Color {
        switch self {
        case .weight:
            return AppPalette.Gym.c600
        case .reps:
            return AppPalette.Gym.c500
        }
    }

    func value(for point: GymHistoryPoint) -> Double {
        switch self {
        case .weight:
            return point.weightKg
        case .reps:
            return Double(point.reps)
        }
    }
}

private struct GymMiniTrendChart: View {
    let points: [GymHistoryPoint]
    let metric: GymHistoryMetric
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

            Chart(points) { point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value(metric.title, metric.value(for: point))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(metric.tint)

                PointMark(
                    x: .value("Fecha", point.date),
                    y: .value(metric.title, metric.value(for: point))
                )
                .symbolSize(34)
                .foregroundStyle(metric.tint)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(
                                date.formatted(
                                    .dateTime
                                        .locale(locale)
                                        .day()
                                        .month(.abbreviated)
                                )
                            )
                            .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYScale(domain: yDomain)
            .frame(height: 120)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(metric.tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { metric.value(for: $0) }
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        if abs(maxValue - minValue) < 0.001 {
            let padding = max(maxValue * 0.05, 1)
            return (minValue - padding)...(maxValue + padding)
        }
        let padding = max((maxValue - minValue) * 0.12, 0.6)
        return (minValue - padding)...(maxValue + padding)
    }
}

private struct GymEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin rutinas todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Crea tu primera rutina y registra ejercicios con peso y tiempos de descanso.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Crear rutina") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Gym.c600)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct GymRoutineCard: View {
    let routine: GymRoutine
    let orderedExercises: [GymExercise]
    let session: RoutineSessionState
    let setWeightForExercise: (GymExercise) -> Double
    let onEditRoutine: () -> Void
    let onAddExercise: () -> Void
    let onStartRoutine: () -> Void
    let onResetRoutine: () -> Void
    let onDecreaseSetWeight: (GymExercise) -> Void
    let onIncreaseSetWeight: (GymExercise) -> Void
    let onCompleteExercise: (GymExercise) -> Void
    let onSelectExercise: (GymExercise) -> Void

    private var totalSets: Int {
        orderedExercises.map(\.sets).reduce(0, +)
    }

    private var completedSets: Int {
        orderedExercises.reduce(0) { partial, exercise in
            partial + min(session.completedSetsByExercise[exercise.id] ?? 0, exercise.sets)
        }
    }

    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    private var activeExercise: GymExercise? {
        guard let currentID = session.currentExerciseID else { return nil }
        return orderedExercises.first { $0.id == currentID }
    }

    private var restingExercise: GymExercise? {
        guard let restingID = session.restingExerciseID else { return nil }
        return orderedExercises.first { $0.id == restingID }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        let secondsText = remaining < 10 ? "0\(remaining)" : "\(remaining)"
        return "\(minutes):\(secondsText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    onEditRoutine()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(routine.name)
                            .font(.headline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.appTextPrimary)

                        Label(routine.scheduledWeekday.displayName, systemImage: "calendar")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppPalette.Gym.c500)

                        if !routine.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(routine.note)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        Text("\(orderedExercises.count) ejercicios")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !orderedExercises.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        session.isStarted ? onResetRoutine() : onStartRoutine()
                    } label: {
                        Label(
                            session.isStarted ? "Reiniciar" : "Iniciar",
                            systemImage: session.isStarted ? "arrow.counterclockwise" : "play.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.Gym.c600)

                    Spacer()

                    Text("\(completedSets)/\(totalSets) series")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }

                if session.restRemainingSeconds > 0, let restingExercise {
                    Label(
                        "Descanso \(formattedDuration(session.restRemainingSeconds)) para \(restingExercise.name) · serie \(session.restingSetNumber ?? 1)/\(restingExercise.sets)",
                        systemImage: "timer"
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.90, green: 0.45, blue: 0.18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                } else if session.isStarted, let activeExercise {
                    Label(
                        "Actual: \(activeExercise.name) · serie \(session.currentSetNumber)/\(activeExercise.sets)",
                        systemImage: "figure.walk"
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.Gym.c500)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                } else if session.isStarted, completedSets == totalSets {
                    Label("Rutina completada", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.09, green: 0.61, blue: 0.37))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.13), in: Capsule())
                }

                ProgressView(value: progress)
                    .tint(AppPalette.Gym.c600)
            }

            if orderedExercises.isEmpty {
                Text("Agrega tu primer ejercicio para esta rutina.")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 8) {
                    ForEach(orderedExercises, id: \.id) { exercise in
                        let completedSetCount = session.completedSetsByExercise[exercise.id] ?? 0

                        GymExerciseRow(
                            exercise: exercise,
                            isRoutineStarted: session.isStarted,
                            isCurrent: session.currentExerciseID == exercise.id,
                            currentSetNumber: session.currentExerciseID == exercise.id ? session.currentSetNumber : nil,
                            completedSetCount: completedSetCount,
                            isCompleted: completedSetCount >= exercise.sets,
                            isRestingTarget: session.restingExerciseID == exercise.id,
                            restRemainingSeconds: session.restingExerciseID == exercise.id ? session.restRemainingSeconds : nil,
                            setWeightKg: setWeightForExercise(exercise),
                            onDecreaseSetWeight: { onDecreaseSetWeight(exercise) },
                            onIncreaseSetWeight: { onIncreaseSetWeight(exercise) },
                            onCheckTap: { onCompleteExercise(exercise) },
                            onOpenEdit: { onSelectExercise(exercise) }
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct GymExerciseRow: View {
    let exercise: GymExercise
    let isRoutineStarted: Bool
    let isCurrent: Bool
    let currentSetNumber: Int?
    let completedSetCount: Int
    let isCompleted: Bool
    let isRestingTarget: Bool
    let restRemainingSeconds: Int?
    let setWeightKg: Double
    let onDecreaseSetWeight: () -> Void
    let onIncreaseSetWeight: () -> Void
    let onCheckTap: () -> Void
    let onOpenEdit: () -> Void

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        let secondsText = remaining < 10 ? "0\(remaining)" : "\(remaining)"
        return "\(minutes):\(secondsText)"
    }

    private var checkIcon: String {
        if isCompleted {
            return "checkmark.circle.fill"
        }
        if isCurrent && isRoutineStarted {
            return "checkmark.circle"
        }
        if isRestingTarget {
            return "timer.circle"
        }
        return "circle"
    }

    private var checkColor: Color {
        if isCompleted {
            return Color(red: 0.09, green: 0.61, blue: 0.37)
        }
        if isCurrent && isRoutineStarted {
            return AppPalette.Gym.c500
        }
        if isRestingTarget {
            return Color(red: 0.90, green: 0.45, blue: 0.18)
        }
        return Color.appTextSecondary
    }

    private var isCheckEnabled: Bool {
        isRoutineStarted && isCurrent && !isCompleted
    }

    private var displayWeightKg: Double {
        if isRoutineStarted && isCurrent && !isCompleted {
            return max(setWeightKg, 0)
        }
        return max(exercise.weightKg, 0)
    }

    private var currentSetVolumeKg: Double {
        displayWeightKg * Double(max(exercise.reps, 0))
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onCheckTap()
            } label: {
                Image(systemName: checkIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(checkColor)
            }
            .buttonStyle(.plain)
            .disabled(!isCheckEnabled)

            Button {
                onOpenEdit()
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.appTextPrimary)

                        if let restRemainingSeconds, isRestingTarget, restRemainingSeconds > 0 {
                            Text("Siguiente serie en \(formattedDuration(restRemainingSeconds)) · \(completedSetCount)/\(exercise.sets) series")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.90, green: 0.45, blue: 0.18))
                        } else if isCurrent && isRoutineStarted {
                            Text("Serie actual \(currentSetNumber ?? 1)/\(exercise.sets) · \(exercise.reps) reps · descanso \(exercise.restSeconds)s")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.Gym.c500)
                        } else if isCompleted {
                            Text("Completado \(exercise.sets)/\(exercise.sets) series")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.09, green: 0.61, blue: 0.37))
                        } else {
                            Text("\(completedSetCount)/\(exercise.sets) series · \(exercise.reps) reps · descanso \(exercise.restSeconds)s")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        if isRoutineStarted && isCurrent && !isCompleted {
                            HStack(spacing: 8) {
                                Text("Peso de serie")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.appTextSecondary)

                                Spacer(minLength: 6)

                                Button {
                                    onDecreaseSetWeight()
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Gym.c600)
                                        .frame(width: 20, height: 20)
                                        .background(AppPalette.Gym.c600.opacity(0.16), in: Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(displayWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppPalette.Gym.c600)
                                    .monospacedDigit()

                                Button {
                                    onIncreaseSetWeight()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Gym.c600)
                                        .frame(width: 20, height: 20)
                                        .background(AppPalette.Gym.c600.opacity(0.16), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(displayWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            .font(.subheadline.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(AppPalette.Gym.c600)

                        if isRoutineStarted && isCurrent && !isCompleted {
                            Text("Vol serie \(currentSetVolumeKg.formatted(.number.precision(.fractionLength(0)))) kg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.appTextSecondary)
                        } else {
                            Text("Vol \(exercise.trainingVolumeKg.formatted(.number.precision(.fractionLength(0)))) kg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }
}

private struct AddGymRoutineView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var note = ""
    @State private var weekday: RoutineWeekday = .monday
    @FocusState private var focusedField: RoutineField?

    let onSave: (_ name: String, _ note: String, _ weekday: RoutineWeekday) -> Void

    private enum RoutineField {
        case name
        case note
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tu rutina" : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GymBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Nombre")
                            } icon: {
                                Image(systemName: "textformat")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            TextField("", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .name
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            Label {
                                Text("Nota (opcional)")
                            } icon: {
                                Image(systemName: "note.text")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            TextField("", text: $note, axis: .vertical)
                                .lineLimit(3...5)
                                .focused($focusedField, equals: .note)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(minHeight: 88, alignment: .topLeading)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .note
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            Label {
                                Text("Dia de rutina")
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            Picker("Dia de rutina", selection: $weekday) {
                                ForEach(RoutineWeekday.allCases) { day in
                                    Text(day.displayName).tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppPalette.Gym.c600)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppPalette.Gym.c600.opacity(0.24), lineWidth: 1)
                            )
                        }
                        .padding(14)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vista previa")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)
                            Text(previewName)
                                .font(.headline.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextPrimary)
                            Text("Dia: \(weekday.displayName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.Gym.c500)
                            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(note.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.appField,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Nueva rutina")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Gym.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(name, note, weekday)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct EditGymRoutineView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var note: String
    @State private var weekday: RoutineWeekday
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: RoutineField?

    let onSave: (_ name: String, _ note: String, _ weekday: RoutineWeekday) -> Void
    let onDelete: () -> Void

    private enum RoutineField {
        case name
        case note
    }

    init(
        routine: GymRoutine,
        onSave: @escaping (_ name: String, _ note: String, _ weekday: RoutineWeekday) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: routine.name)
        _note = State(initialValue: routine.note)
        _weekday = State(initialValue: routine.scheduledWeekday)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tu rutina" : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GymBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Nombre")
                            } icon: {
                                Image(systemName: "textformat")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            TextField("", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .name
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            Label {
                                Text("Nota (opcional)")
                            } icon: {
                                Image(systemName: "note.text")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            TextField("", text: $note, axis: .vertical)
                                .lineLimit(3...5)
                                .focused($focusedField, equals: .note)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(minHeight: 88, alignment: .topLeading)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .note
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            Label {
                                Text("Dia de rutina")
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            Picker("Dia de rutina", selection: $weekday) {
                                ForEach(RoutineWeekday.allCases) { day in
                                    Text(day.displayName).tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppPalette.Gym.c600)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppPalette.Gym.c600.opacity(0.24), lineWidth: 1)
                            )
                        }
                        .padding(14)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vista previa")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)
                            Text(previewName)
                                .font(.headline.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextPrimary)
                            Text("Dia: \(weekday.displayName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.Gym.c500)
                            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(note.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.appField,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eliminar rutina")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Eliminar rutina", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color(red: 1.00, green: 0.94, blue: 0.95),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(red: 0.90, green: 0.20, blue: 0.22).opacity(0.25), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Editar rutina")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Gym.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Actualizar") {
                        onSave(name, note, weekday)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Eliminar rutina", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Se eliminara la rutina y todos sus ejercicios.")
            }
        }
    }
}

private struct AddGymExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var sets: Int
    @State private var reps: Int
    @State private var weightInput: Double
    @State private var weightUnit: WeightUnit
    @State private var restSeconds: Int
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: ExerciseField?

    let routineName: String
    private let isEditing: Bool
    let onSave: (_ name: String, _ sets: Int, _ reps: Int, _ weightKg: Double, _ restSeconds: Int) -> Void
    let onDelete: (() -> Void)?

    private enum WeightUnit: String, CaseIterable, Identifiable {
        case kg = "kg"
        case lb = "lb"

        var id: String { rawValue }
    }

    private enum ExerciseField {
        case name
        case weight
    }

    init(
        routineName: String,
        initialExercise: GymExercise? = nil,
        onSave: @escaping (_ name: String, _ sets: Int, _ reps: Int, _ weightKg: Double, _ restSeconds: Int) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.routineName = routineName
        self.isEditing = initialExercise != nil
        self.onSave = onSave
        self.onDelete = onDelete

        if let initialExercise {
            _name = State(initialValue: initialExercise.name)
            _sets = State(initialValue: initialExercise.sets)
            _reps = State(initialValue: initialExercise.reps)
            _weightInput = State(initialValue: max(initialExercise.weightKg, 0))
            _weightUnit = State(initialValue: .kg)
            _restSeconds = State(initialValue: initialExercise.restSeconds)
        } else {
            _name = State(initialValue: "")
            _sets = State(initialValue: 4)
            _reps = State(initialValue: 10)
            _weightInput = State(initialValue: 20)
            _weightUnit = State(initialValue: .kg)
            _restSeconds = State(initialValue: 90)
        }
    }

    private let poundsPerKilogram = 2.2046226218

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewExerciseName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ejercicio" : trimmed
    }

    private var normalizedWeightInput: Double {
        max(weightInput, 0)
    }

    private var weightInKg: Double {
        switch weightUnit {
        case .kg:
            return normalizedWeightInput
        case .lb:
            return normalizedWeightInput / poundsPerKilogram
        }
    }

    private var convertedWeightValue: Double {
        switch weightUnit {
        case .kg:
            return normalizedWeightInput * poundsPerKilogram
        case .lb:
            return weightInKg
        }
    }

    private var convertedWeightUnit: String {
        switch weightUnit {
        case .kg:
            return "lb"
        case .lb:
            return "kg"
        }
    }

    private var previewVolume: Double {
        Double(sets * reps) * weightInKg
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GymBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rutina")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)

                            Text(routineName)
                                .font(.subheadline.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextPrimary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Ejercicio")
                            } icon: {
                                Image(systemName: "figure.strengthtraining.traditional")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                            TextField("", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .name
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            ExerciseStepperRow(
                                title: "Series",
                                valueText: "\(sets)",
                                onMinus: { sets = max(1, sets - 1) },
                                onPlus: { sets = min(12, sets + 1) }
                            )

                            ExerciseStepperRow(
                                title: "Repeticiones",
                                valueText: "\(reps)",
                                onMinus: { reps = max(1, reps - 1) },
                                onPlus: { reps = min(30, reps + 1) }
                            )

                            Label {
                                Text("Peso")
                            } icon: {
                                Image(systemName: "scalemass")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.top, 2)

                            Picker("Unidad de peso", selection: $weightUnit) {
                                ForEach(WeightUnit.allCases) { unit in
                                    Text(unit.rawValue.uppercased()).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(AppPalette.Gym.c600)

                            TextField("", value: $weightInput, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .weight)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            focusedField == .weight
                                            ? AppPalette.Gym.c600.opacity(0.50)
                                            : AppPalette.Gym.c600.opacity(0.24),
                                            lineWidth: 1
                                        )
                                )

                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppPalette.Gym.c600)
                                Text("Equivale a")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.appTextSecondary)
                                Spacer()
                                Text("\(convertedWeightValue.formatted(.number.precision(.fractionLength(0...2)))) \(convertedWeightUnit)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )

                            ExerciseStepperRow(
                                title: "Descanso",
                                valueText: "\(restSeconds)s",
                                onMinus: { restSeconds = max(15, restSeconds - 15) },
                                onPlus: { restSeconds = min(300, restSeconds + 15) }
                            )
                        }
                        .padding(14)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vista previa")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)

                            Text(previewExerciseName)
                                .font(.headline.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextPrimary)

                            Text("\(sets)x\(reps) · \(normalizedWeightInput.formatted(.number.precision(.fractionLength(0...2)))) \(weightUnit.rawValue) · descanso \(restSeconds)s")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)

                            Text("Volumen: \(previewVolume.formatted(.number.precision(.fractionLength(0)))) kg")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.Gym.c600)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.appField,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )

                        if isEditing, onDelete != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eliminar ejercicio")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar ejercicio", systemImage: "trash.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(red: 1.00, green: 0.94, blue: 0.95),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 0.90, green: 0.20, blue: 0.22).opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(isEditing ? "Editar ejercicio" : "Nuevo ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Gym.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(name, sets, reps, weightInKg, restSeconds)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: weightUnit) { oldUnit, newUnit in
                guard oldUnit != newUnit else { return }

                switch (oldUnit, newUnit) {
                case (.kg, .lb):
                    weightInput = normalizedWeightInput * poundsPerKilogram
                case (.lb, .kg):
                    weightInput = normalizedWeightInput / poundsPerKilogram
                default:
                    break
                }
            }
            .alert("Eliminar ejercicio", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Este ejercicio se eliminara de la rutina.")
            }
        }
    }
}

private struct ExerciseStepperRow: View {
    let title: String
    let valueText: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.Gym.c600)
                    .frame(width: 28, height: 28)
                    .background(AppPalette.Gym.c600.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Text(valueText)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)
                .frame(minWidth: 46, alignment: .center)

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.Gym.c600)
                    .frame(width: 28, height: 28)
                    .background(AppPalette.Gym.c600.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.Gym.c600.opacity(0.24), lineWidth: 1)
        )
    }
}

private extension GymExercise {
    var trainingVolumeKg: Double {
        Double(sets * reps) * weightKg
    }
}
