import SwiftUI
import SwiftData
import OSLog

private struct FoodGoalSummary {
    let isTrainingDay: Bool
    let targetCalories: Int
    let targetProteinGrams: Int
    let remainingCalories: Int
    let remainingProteinGrams: Int
    let sourceDescription: String
}

private struct FoodRecommendation: Identifiable {
    let mealType: FoodMealType
    let title: String
    let calories: Int
    let proteinGrams: Int
    let reason: String

    var id: String {
        "\(mealType.rawValue)-\(title.lowercased())-\(reason.lowercased())"
    }
}

private struct FoodHistoryAggregate {
    let name: String
    let usesCount: Int
    let monthCount: Int
    let usedYesterday: Bool
    let lastDate: Date
    let avgCalories: Int
    let avgProteinGrams: Int
}

private struct FoodFallbackTemplate {
    let mealType: FoodMealType
    let name: String
    let calories: Int
    let proteinGrams: Int
}

private struct FoodEditTarget: Identifiable {
    let id: UUID
}

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query(sort: \GymSetRecord.performedAt, order: .reverse) private var setRecords: [GymSetRecord]
    @Query(sort: \BodyMeasurementEntry.date, order: .reverse) private var bodyMeasurements: [BodyMeasurementEntry]
    @AppStorage("food.goal.targetWeightKg") private var targetWeightStorage: Double = 0

    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    @State private var editTarget: FoodEditTarget?
    @State private var cachedRecommendationSections: [(FoodMealType, [FoodRecommendation])] = []
    @State private var recommendationsRefreshTask: Task<Void, Never>?

    private var dayEntries: [FoodEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var totalCalories: Int {
        dayEntries.map(\.calories).reduce(0, +)
    }

    private var totalProteinGrams: Int {
        dayEntries.reduce(0) { partial, entry in
            partial + Int((entry.proteinGrams ?? 0).rounded())
        }
    }

    private var mealSections: [(FoodMealType, [FoodEntry])] {
        FoodMealType.allCases.compactMap { type in
            let grouped = dayEntries.filter { $0.mealType == type }
            return grouped.isEmpty ? nil : (type, grouped)
        }
    }

    private var latestBodyWeightKg: Double? {
        bodyMeasurements.first(where: { ($0.weightKg ?? 0) > 0 })?.weightKg
    }

    private var currentTargetWeightKg: Double {
        if targetWeightStorage > 0 {
            return max(targetWeightStorage, 35)
        }
        if let latestBodyWeightKg {
            return max(latestBodyWeightKg, 35)
        }
        return 75
    }

    private var isTrainingDay: Bool {
        setRecords.contains {
            Calendar.current.isDate($0.performedAt, inSameDayAs: selectedDate)
        }
    }

    private var nutritionGoal: FoodGoalSummary {
        let averageCalories = averageDailyCaloriesLast30Days(referenceDate: selectedDate)
        let baselineCalories: Int
        let sourceDescription: String
        if averageCalories > 0 {
            baselineCalories = Int((averageCalories * 0.88).rounded())
            sourceDescription = "Meta por historial: -12% de promedio de 30 dias."
        } else {
            baselineCalories = Int((currentTargetWeightKg * 26).rounded())
            sourceDescription = "Meta estimada por peso objetivo."
        }

        let workoutAdjusted = baselineCalories + (isTrainingDay ? 120 : -80)
        let targetCalories = min(max(workoutAdjusted, 1400), 3800)
        let targetProtein = max(Int((currentTargetWeightKg * 2.0).rounded()), 90)

        return FoodGoalSummary(
            isTrainingDay: isTrainingDay,
            targetCalories: targetCalories,
            targetProteinGrams: targetProtein,
            remainingCalories: targetCalories - totalCalories,
            remainingProteinGrams: targetProtein - totalProteinGrams,
            sourceDescription: sourceDescription
        )
    }

    private var recommendationSections: [(FoodMealType, [FoodRecommendation])] {
        if cachedRecommendationSections.isEmpty {
            return FoodMealType.allCases.map { mealType in
                (mealType, recommendations(for: mealType))
            }
        }
        return cachedRecommendationSections
    }

    private var recommendationsRefreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(Calendar.current.startOfDay(for: selectedDate))
        hasher.combine(entries.count)
        hasher.combine(setRecords.count)
        hasher.combine(bodyMeasurements.count)
        hasher.combine(Int((targetWeightStorage * 10).rounded()))
        hasher.combine(entries.first?.id)
        hasher.combine(setRecords.first?.id)
        hasher.combine(bodyMeasurements.first?.id)
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FoodBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        FoodSummaryCard(
                            selectedDate: selectedDate,
                            totalEntries: dayEntries.count,
                            totalCalories: totalCalories,
                            totalProteinGrams: totalProteinGrams
                        )

                        FoodGoalCard(
                            latestWeightKg: latestBodyWeightKg,
                            targetWeightKg: currentTargetWeightKg,
                            summary: nutritionGoal,
                            onDecreaseTarget: { updateTargetWeight(by: -0.5) },
                            onIncreaseTarget: { updateTargetWeight(by: 0.5) }
                        )

                        FoodRecommendationsCard(
                            sections: recommendationSections,
                            remainingCalories: nutritionGoal.remainingCalories,
                            remainingProteinGrams: nutritionGoal.remainingProteinGrams
                        )

                        FeatureSectionHeader(title: "Alimentos") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nuevo", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Food.c600)
                        }

                        if dayEntries.isEmpty {
                            FoodEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(mealSections, id: \.0.id) { section in
                                    FoodMealSectionCard(
                                        mealType: section.0,
                                        entries: section.1,
                                        onSelectEntry: { entry in
                                            editTarget = FoodEditTarget(id: entry.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Comidas")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddFoodEntryView(initialDate: selectedDate) { name, mealType, quantity, calories, proteinGrams, note, date in
                    createEntry(
                        name: name,
                        mealType: mealType,
                        quantity: quantity,
                        calories: calories,
                        proteinGrams: proteinGrams,
                        note: note,
                        date: date
                    )
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedEntryForEditing = entries.first(where: { $0.id == target.id }) {
                    AddFoodEntryView(
                        initialDate: selectedDate,
                        initialEntry: selectedEntryForEditing
                    ) { name, mealType, quantity, calories, proteinGrams, note, date in
                        updateEntry(
                            selectedEntryForEditing,
                            name: name,
                            mealType: mealType,
                            quantity: quantity,
                            calories: calories,
                            proteinGrams: proteinGrams,
                            note: note,
                            date: date
                        )
                    } onDelete: {
                        delete(selectedEntryForEditing)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Alimento no disponible",
                            systemImage: "fork.knife",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
            .animation(.snappy(duration: 0.3), value: dayEntries.count)
            .onAppear {
                scheduleRecommendationRecompute(immediate: true)
            }
            .onChange(of: recommendationsRefreshSignature) { _, _ in
                scheduleRecommendationRecompute()
            }
            .onDisappear {
                recommendationsRefreshTask?.cancel()
                recommendationsRefreshTask = nil
            }
        }
    }

    private func scheduleRecommendationRecompute(immediate: Bool = false) {
        recommendationsRefreshTask?.cancel()
        recommendationsRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard !Task.isCancelled else { return }
            recomputeRecommendationSections()
        }
    }

    private func recomputeRecommendationSections() {
        let interval = Observability.foodSignposter.beginInterval("food.recommendations.recompute")
        defer { Observability.foodSignposter.endInterval("food.recommendations.recompute", interval) }
        cachedRecommendationSections = FoodMealType.allCases.map { mealType in
            (mealType, recommendations(for: mealType))
        }
        Observability.debug(
            Observability.foodLogger,
            "Recommendations recomputed. sections: \(cachedRecommendationSections.count), entries: \(entries.count)"
        )
    }

    private func updateTargetWeight(by delta: Double) {
        let base = targetWeightStorage > 0 ? targetWeightStorage : currentTargetWeightKg
        targetWeightStorage = min(max(base + delta, 35), 220)
    }

    private func averageDailyCaloriesLast30Days(referenceDate: Date) -> Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: dayStart) else { return 0 }

        let recentEntries = entries.filter { $0.date >= startDate && $0.date < dayStart }
        guard !recentEntries.isEmpty else { return 0 }

        let groupedByDay = Dictionary(grouping: recentEntries) { calendar.startOfDay(for: $0.date) }
        let dailyCalories = groupedByDay.values.map { dayEntries in
            dayEntries.map(\.calories).reduce(0, +)
        }
        guard !dailyCalories.isEmpty else { return 0 }

        return Double(dailyCalories.reduce(0, +)) / Double(dailyCalories.count)
    }

    private func recommendations(for mealType: FoodMealType) -> [FoodRecommendation] {
        let aggregates = historyAggregates(for: mealType)
        var result: [FoodRecommendation] = aggregates.prefix(2).map { aggregate in
            FoodRecommendation(
                mealType: mealType,
                title: aggregate.name,
                calories: aggregate.avgCalories,
                proteinGrams: aggregate.avgProteinGrams,
                reason: historyReason(for: aggregate)
            )
        }

        let templates = fallbackTemplates(for: mealType)
        guard !templates.isEmpty else { return Array(result.prefix(3)) }

        let focusedTemplate = macroFocusedTemplate(
            for: mealType,
            remainingCalories: nutritionGoal.remainingCalories,
            remainingProtein: nutritionGoal.remainingProteinGrams
        )

        var orderedTemplates = templates
        if let focusedTemplate {
            orderedTemplates.removeAll { normalizedFoodName($0.name) == normalizedFoodName(focusedTemplate.name) }
            orderedTemplates.insert(focusedTemplate, at: 0)
        }

        var usedNames = Set(result.map { normalizedFoodName($0.title) })
        for template in orderedTemplates {
            guard result.count < 3 else { break }
            let normalized = normalizedFoodName(template.name)
            guard !usedNames.contains(normalized) else { continue }

            result.append(
                FoodRecommendation(
                    mealType: template.mealType,
                    title: template.name,
                    calories: template.calories,
                    proteinGrams: template.proteinGrams,
                    reason: fallbackReason(
                        for: template,
                        remainingCalories: nutritionGoal.remainingCalories,
                        remainingProtein: nutritionGoal.remainingProteinGrams
                    )
                )
            )
            usedNames.insert(normalized)
        }

        return Array(result.prefix(3))
    }

    private func historyAggregates(for mealType: FoodMealType) -> [FoodHistoryAggregate] {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: selectedDate)
        guard
            let startDate = calendar.date(byAdding: .day, value: -45, to: referenceDay),
            let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDay)
        else {
            return []
        }

        let recentEntries = entries.filter {
            $0.mealType == mealType &&
            $0.date >= startDate &&
            $0.date < referenceDay
        }

        let grouped = Dictionary(grouping: recentEntries) { entry in
            normalizedFoodName(entry.name)
        }.filter { !$0.key.isEmpty }

        let aggregates = grouped.compactMap { _, groupedEntries -> FoodHistoryAggregate? in
            let sortedByDate = groupedEntries.sorted { $0.date > $1.date }
            guard let latest = sortedByDate.first else { return nil }

            let displayName = latest.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let caloriesValues = groupedEntries.map(\.calories).filter { $0 > 0 }
            let avgCalories: Int
            if caloriesValues.isEmpty {
                avgCalories = defaultCalories(for: mealType)
            } else {
                let sum = caloriesValues.reduce(0, +)
                avgCalories = Int((Double(sum) / Double(caloriesValues.count)).rounded())
            }

            let proteinValues = groupedEntries.compactMap(\.proteinGrams).filter { $0 > 0 }
            let avgProtein: Int
            if proteinValues.isEmpty {
                avgProtein = estimatedProtein(for: displayName, calories: avgCalories) ?? defaultProtein(for: mealType)
            } else {
                avgProtein = Int((proteinValues.reduce(0, +) / Double(proteinValues.count)).rounded())
            }

            let monthCount = groupedEntries.filter {
                calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month)
            }.count

            return FoodHistoryAggregate(
                name: displayName,
                usesCount: groupedEntries.count,
                monthCount: monthCount,
                usedYesterday: groupedEntries.contains { calendar.isDate($0.date, inSameDayAs: yesterday) },
                lastDate: latest.date,
                avgCalories: max(avgCalories, 0),
                avgProteinGrams: max(avgProtein, 0)
            )
        }

        return aggregates.sorted { lhs, rhs in
            if lhs.usedYesterday != rhs.usedYesterday {
                return lhs.usedYesterday && !rhs.usedYesterday
            }
            if lhs.monthCount != rhs.monthCount {
                return lhs.monthCount > rhs.monthCount
            }
            if lhs.usesCount != rhs.usesCount {
                return lhs.usesCount > rhs.usesCount
            }
            return lhs.lastDate > rhs.lastDate
        }
    }

    private func historyReason(for aggregate: FoodHistoryAggregate) -> String {
        if aggregate.usedYesterday {
            return "La comiste ayer y te ha funcionado en tu dia."
        }
        if aggregate.monthCount >= 3 {
            return "La repetiste \(aggregate.monthCount)x este mes."
        }
        if aggregate.usesCount >= 2 {
            return "Sale seguido en tu historial reciente."
        }
        return "Aparece en tu historial del ultimo mes."
    }

    private func fallbackReason(
        for template: FoodFallbackTemplate,
        remainingCalories: Int,
        remainingProtein: Int
    ) -> String {
        if remainingProtein > 25 && template.proteinGrams >= 25 {
            return "Prioriza proteina para ganar musculo."
        }
        if remainingCalories < 320 && template.calories <= 320 {
            return "Opcion ligera para cerrar el dia."
        }
        if remainingCalories > 650 && template.calories >= 420 {
            return "Te ayuda a completar energia del dia."
        }
        return "Opcion balanceada para tus metas."
    }

    private func macroFocusedTemplate(
        for mealType: FoodMealType,
        remainingCalories: Int,
        remainingProtein: Int
    ) -> FoodFallbackTemplate? {
        let templates = fallbackTemplates(for: mealType)
        guard !templates.isEmpty else { return nil }

        if remainingProtein > 30 {
            return templates.max { lhs, rhs in
                lhs.proteinGrams < rhs.proteinGrams
            }
        }

        if remainingCalories < 350 {
            return templates.min { lhs, rhs in
                lhs.calories < rhs.calories
            }
        }

        let targetCalories = max(min(remainingCalories, 700), 320)
        return templates.min { lhs, rhs in
            abs(lhs.calories - targetCalories) < abs(rhs.calories - targetCalories)
        }
    }

    private func fallbackTemplates(for mealType: FoodMealType) -> [FoodFallbackTemplate] {
        switch mealType {
        case .breakfast:
            return [
                FoodFallbackTemplate(mealType: .breakfast, name: "Huevos con claras", calories: 340, proteinGrams: 32),
                FoodFallbackTemplate(mealType: .breakfast, name: "Avena con proteina", calories: 410, proteinGrams: 34),
                FoodFallbackTemplate(mealType: .breakfast, name: "Yogurt griego con fruta", calories: 280, proteinGrams: 24)
            ]
        case .lunch:
            return [
                FoodFallbackTemplate(mealType: .lunch, name: "Pollo con arroz y verduras", calories: 620, proteinGrams: 45),
                FoodFallbackTemplate(mealType: .lunch, name: "Atun con papa cocida", calories: 500, proteinGrams: 40),
                FoodFallbackTemplate(mealType: .lunch, name: "Carne magra con ensalada", calories: 540, proteinGrams: 42)
            ]
        case .dinner:
            return [
                FoodFallbackTemplate(mealType: .dinner, name: "Pescado con verduras", calories: 430, proteinGrams: 38),
                FoodFallbackTemplate(mealType: .dinner, name: "Tortilla de claras con queso", calories: 360, proteinGrams: 34),
                FoodFallbackTemplate(mealType: .dinner, name: "Wrap integral de pollo", calories: 470, proteinGrams: 36)
            ]
        case .snack:
            return [
                FoodFallbackTemplate(mealType: .snack, name: "Batido de proteina", calories: 210, proteinGrams: 28),
                FoodFallbackTemplate(mealType: .snack, name: "Yogurt griego natural", calories: 170, proteinGrams: 19),
                FoodFallbackTemplate(mealType: .snack, name: "Queso cottage con fruta", calories: 220, proteinGrams: 21)
            ]
        }
    }

    private func defaultCalories(for mealType: FoodMealType) -> Int {
        switch mealType {
        case .breakfast:
            return 380
        case .lunch:
            return 560
        case .dinner:
            return 500
        case .snack:
            return 220
        }
    }

    private func defaultProtein(for mealType: FoodMealType) -> Int {
        switch mealType {
        case .breakfast:
            return 26
        case .lunch:
            return 36
        case .dinner:
            return 32
        case .snack:
            return 18
        }
    }

    private func estimatedProtein(for foodName: String, calories: Int) -> Int? {
        let normalized = foodName.lowercased()
        let hints: [(String, Int)] = [
            ("pollo", 40),
            ("atun", 36),
            ("huevo", 28),
            ("claras", 30),
            ("carne", 38),
            ("res", 36),
            ("pescado", 34),
            ("salmon", 34),
            ("yogurt", 20),
            ("proteina", 28),
            ("queso", 22),
            ("cottage", 24)
        ]

        if let exact = hints.first(where: { normalized.contains($0.0) }) {
            return exact.1
        }

        guard calories > 0 else { return nil }
        return max(Int((Double(calories) * 0.08).rounded()), 10)
    }

    private func normalizedFoodName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func createEntry(
        name: String,
        mealType: FoodMealType,
        quantity: String,
        calories: Int,
        proteinGrams: Int,
        note: String,
        date: Date
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = FoodEntry(
            name: trimmedName,
            mealType: mealType,
            quantity: quantity.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: max(calories, 0),
            proteinGrams: proteinGrams > 0 ? Double(proteinGrams) : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(entry)
        }
    }

    private func updateEntry(
        _ entry: FoodEntry,
        name: String,
        mealType: FoodMealType,
        quantity: String,
        calories: Int,
        proteinGrams: Int,
        note: String,
        date: Date
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            entry.name = trimmedName
            entry.mealType = mealType
            entry.quantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.calories = max(calories, 0)
            entry.proteinGrams = proteinGrams > 0 ? Double(proteinGrams) : nil
            entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.date = date
        }
    }

    private func delete(_ entry: FoodEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(entry)
        }
        if editTarget?.id == entry.id {
            editTarget = nil
        }
    }
}

private struct FoodBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .food)
    }
}

private struct FoodSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let selectedDate: Date
    let totalEntries: Int
    let totalCalories: Int
    let totalProteinGrams: Int

    private var dateText: String {
        AppDateFormatters.esMXLongWeekdayDayMonth.string(from: selectedDate).capitalized
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Food.c900, AppPalette.Food.c700]
        }
        return [AppPalette.Food.c600, AppPalette.Food.c400]
    }

    private var strokeColor: Color {
        .white.opacity(colorScheme == .dark ? 0.18 : 0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registro diario")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            Text(dateText)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                FoodMetricPill(title: "Alimentos", value: "\(totalEntries)")
                FoodMetricPill(title: "Calorias", value: "\(totalCalories) kcal")
                FoodMetricPill(title: "Proteina", value: "\(totalProteinGrams) g")
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
    }
}

private struct FoodMetricPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.82 : 0.92))

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

private struct FoodGoalCard: View {
    let latestWeightKg: Double?
    let targetWeightKg: Double
    let summary: FoodGoalSummary
    let onDecreaseTarget: () -> Void
    let onIncreaseTarget: () -> Void

    private var statusTitle: String {
        summary.isTrainingDay ? "Dia de entrenamiento" : "Dia de descanso"
    }

    private var statusTint: Color {
        summary.isTrainingDay ? AppPalette.Gym.c600 : AppPalette.Food.c700
    }

    private func formatWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Objetivo diario")
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusTint.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Peso objetivo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)

                    HStack(spacing: 10) {
                        Button(action: onDecreaseTarget) {
                            Image(systemName: "minus")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppPalette.Food.c700)
                                .frame(width: 26, height: 26)
                                .background(AppPalette.Food.c700.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Text("\(formatWeight(targetWeightKg)) kg")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                            .monospacedDigit()

                        Button(action: onIncreaseTarget) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppPalette.Food.c700)
                                .frame(width: 26, height: 26)
                                .background(AppPalette.Food.c700.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if let latestWeightKg {
                        Text("Actual: \(formatWeight(latestWeightKg)) kg")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                    } else {
                        Text("Sin peso corporal guardado")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Text(summary.sourceDescription)
                        .font(.caption2)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                FoodGoalPill(title: "Meta kcal", value: "\(summary.targetCalories)")
                FoodGoalPill(title: "Meta prot", value: "\(summary.targetProteinGrams) g")
                FoodGoalPill(
                    title: "Restante",
                    value: "\(max(summary.remainingProteinGrams, 0)) g"
                )
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

private struct FoodGoalPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct FoodRecommendationsCard: View {
    let sections: [(FoodMealType, [FoodRecommendation])]
    let remainingCalories: Int
    let remainingProteinGrams: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recomendaciones del dia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Basado en hoy, ayer y tu historial del mes.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)

            if sections.allSatisfy({ $0.1.isEmpty }) {
                Text("Agrega alimentos para generar sugerencias personalizadas.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(sections, id: \.0.id) { mealType, items in
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(mealType.displayName, systemImage: mealType.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(mealType.tint)

                                ForEach(items) { recommendation in
                                    FoodRecommendationRow(recommendation: recommendation)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                    }
                }
            }

            if remainingCalories < 0 || remainingProteinGrams < 0 {
                Text("Hoy ya superaste una de tus metas. Ajusta porciones o sube tu meta si es necesario.")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
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

private struct FoodRecommendationRow: View {
    let recommendation: FoodRecommendation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(recommendation.calories) kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()

                Text("\(recommendation.proteinGrams) g prot")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.Gym.c600)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct FoodEmptyStateCard: View {
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin alimentos registrados")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Agrega lo que comiste hoy para llevar tu control diario.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Agregar alimento") {
                onAddTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Food.c600)
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

private struct FoodMealSectionCard: View {
    let mealType: FoodMealType
    let entries: [FoodEntry]
    let onSelectEntry: (FoodEntry) -> Void

    private var calories: Int {
        entries.map(\.calories).reduce(0, +)
    }

    private var proteinGrams: Int {
        entries.reduce(0) { partial, entry in
            partial + Int((entry.proteinGrams ?? 0).rounded())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(mealType.displayName, systemImage: mealType.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(mealType.tint)

                Spacer()

                HStack(spacing: 6) {
                    Text("\(calories) kcal")
                    if proteinGrams > 0 {
                        Text("· \(proteinGrams) g")
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    FoodEntryRow(entry: entry) {
                        onSelectEntry(entry)
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

private struct FoodEntryRow: View {
    let entry: FoodEntry
    let onTap: () -> Void

    private var timeText: String {
        entry.date.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)

                    HStack(spacing: 6) {
                        Text(timeText)
                        if !entry.quantity.isEmpty {
                            Text("· \(entry.quantity)")
                        }
                        if entry.calories > 0 {
                            Text("· \(entry.calories) kcal")
                        }
                        if let proteinGrams = entry.proteinGrams, proteinGrams > 0 {
                            Text("· \(Int(proteinGrams.rounded())) g prot")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum FoodQuantityUnit: String, CaseIterable, Identifiable {
    case grams = "g"
    case kilograms = "kg"
    case milliliters = "ml"
    case liters = "l"
    case ounces = "oz"
    case pounds = "lb"
    case cups = "taza"
    case tablespoons = "cda"
    case teaspoons = "cdta"
    case pieces = "pieza"
    case portions = "porcion"
    case slices = "rebanada"
    case none = "none"

    var id: String { rawValue }

    var displayName: String {
        singularDisplayName
    }

    func displayName(for quantityText: String) -> String {
        usesPlural(for: quantityText) ? pluralDisplayName : singularDisplayName
    }

    private var singularDisplayName: String {
        switch self {
        case .grams:
            return "g"
        case .kilograms:
            return "kg"
        case .milliliters:
            return "ml"
        case .liters:
            return "L"
        case .ounces:
            return "oz"
        case .pounds:
            return "lb"
        case .cups:
            return "taza"
        case .tablespoons:
            return "cda"
        case .teaspoons:
            return "cdta"
        case .pieces:
            return "pieza"
        case .portions:
            return "porcion"
        case .slices:
            return "rebanada"
        case .none:
            return "sin ud."
        }
    }

    private var pluralDisplayName: String {
        switch self {
        case .cups:
            return "tazas"
        case .tablespoons:
            return "cdas"
        case .teaspoons:
            return "cdtas"
        case .pieces:
            return "piezas"
        case .portions:
            return "porciones"
        case .slices:
            return "rebanadas"
        default:
            return singularDisplayName
        }
    }

    var optionTitle: String {
        switch self {
        case .grams:
            return "Gramos (g)"
        case .kilograms:
            return "Kilogramos (kg)"
        case .milliliters:
            return "Mililitros (ml)"
        case .liters:
            return "Litros (L)"
        case .ounces:
            return "Onzas (oz)"
        case .pounds:
            return "Libras (lb)"
        case .cups:
            return "Tazas"
        case .tablespoons:
            return "Cucharadas (cda)"
        case .teaspoons:
            return "Cucharaditas (cdta)"
        case .pieces:
            return "Piezas"
        case .portions:
            return "Porciones"
        case .slices:
            return "Rebanadas"
        case .none:
            return "Sin unidad"
        }
    }

    func symbol(for quantityText: String) -> String? {
        switch self {
        case .none:
            return nil
        case .liters:
            return "L"
        case .cups:
            return usesPlural(for: quantityText) ? "tazas" : "taza"
        case .tablespoons:
            return usesPlural(for: quantityText) ? "cdas" : "cda"
        case .teaspoons:
            return usesPlural(for: quantityText) ? "cdtas" : "cdta"
        case .pieces:
            return usesPlural(for: quantityText) ? "piezas" : "pieza"
        case .portions:
            return usesPlural(for: quantityText) ? "porciones" : "porcion"
        case .slices:
            return usesPlural(for: quantityText) ? "rebanadas" : "rebanada"
        default:
            return rawValue
        }
    }

    private func usesPlural(for quantityText: String) -> Bool {
        guard let value = Self.numericValue(from: quantityText) else { return false }
        return abs(value - 1) > 0.000_001
    }

    private static func numericValue(from quantityText: String) -> Double? {
        let trimmed = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var parseTokens: [String] {
        switch self {
        case .grams:
            return ["g", "gr", "gramo", "gramos"]
        case .kilograms:
            return ["kg", "kilo", "kilos", "kilogramo", "kilogramos"]
        case .milliliters:
            return ["ml", "mililitro", "mililitros"]
        case .liters:
            return ["l", "lt", "litro", "litros"]
        case .ounces:
            return ["oz", "onza", "onzas"]
        case .pounds:
            return ["lb", "libras", "libra"]
        case .cups:
            return ["taza", "tazas"]
        case .tablespoons:
            return ["cda", "cdas", "cucharada", "cucharadas"]
        case .teaspoons:
            return ["cdta", "cdtas", "cucharadita", "cucharaditas"]
        case .pieces:
            return ["pieza", "piezas", "pz"]
        case .portions:
            return ["porcion", "porciones"]
        case .slices:
            return ["rebanada", "rebanadas", "slice", "slices"]
        case .none:
            return []
        }
    }
}

private struct AddFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mealType: FoodMealType = .breakfast
    @State private var quantityValue = ""
    @State private var quantityUnit: FoodQuantityUnit = .grams
    @State private var calories = 0
    @State private var proteinGrams = 0
    @State private var note = ""
    @State private var date: Date
    @State private var showingDeleteAlert = false
    @State private var showingDateTimeSheet = false
    @FocusState private var focusedField: FoodField?

    private let isEditing: Bool
    let onSave: (_ name: String, _ mealType: FoodMealType, _ quantity: String, _ calories: Int, _ proteinGrams: Int, _ note: String, _ date: Date) -> Void
    let onDelete: (() -> Void)?

    private enum FoodField {
        case name
        case quantity
        case note
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var quantityForSave: String {
        let trimmedValue = quantityValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return "" }

        guard let symbol = quantityUnit.symbol(for: trimmedValue) else {
            return trimmedValue
        }
        return "\(trimmedValue) \(symbol)"
    }

    private var quantityUnitLabel: String {
        quantityUnit.displayName(for: quantityValue)
    }

    private static func parseQuantity(_ rawQuantity: String) -> (value: String, unit: FoodQuantityUnit) {
        let trimmed = rawQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", .grams) }

        let lowered = trimmed.lowercased()
        let units = FoodQuantityUnit.allCases.filter { $0 != .none }

        for unit in units {
            for token in unit.parseTokens.sorted(by: { $0.count > $1.count }) {
                if lowered.hasSuffix(" \(token)") {
                    let value = String(trimmed.dropLast(token.count + 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return (value, unit)
                }

                if lowered.hasSuffix(token) {
                    let value = String(trimmed.dropLast(token.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if looksNumeric(value) {
                        return (value, unit)
                    }
                }
            }
        }

        return (trimmed, .none)
    }

    private static func looksNumeric(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789.,")
        let content = CharacterSet(charactersIn: text)
        return content.isSubset(of: allowed)
    }

    private var dateSummaryText: String {
        AppDateFormatters.esMXShortDate.string(from: date).capitalized
    }

    private var timeSummaryText: String {
        AppDateFormatters.esMXTime12h.string(from: date).lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FoodBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            FoodInputLabel(title: "Alimento", systemImage: "fork.knife")

                            TextField("", text: $name)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .name)
                                .foodInputField()

                            FoodInputLabel(title: "Tipo de comida", systemImage: mealType.icon)

                            Menu {
                                ForEach(FoodMealType.allCases) { type in
                                    Button {
                                        mealType = type
                                    } label: {
                                        HStack {
                                            Label(type.displayName, systemImage: type.icon)
                                            if type == mealType {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Label(mealType.displayName, systemImage: mealType.icon)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(mealType.tint)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(mealType.tint.opacity(0.24), lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)

                            FoodInputLabel(title: "Cantidad (opcional)", systemImage: "scalemass")

                            HStack(spacing: 8) {
                                TextField("", text: $quantityValue)
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedField, equals: .quantity)
                                    .foodInputField()

                                Menu {
                                    ForEach(FoodQuantityUnit.allCases) { unit in
                                        Button {
                                            quantityUnit = unit
                                        } label: {
                                            HStack {
                                                Text(unit.optionTitle)
                                                if unit == quantityUnit {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(quantityUnitLabel)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.appTextPrimary)
                                            .lineLimit(1)

                                        Spacer(minLength: 0)

                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(
                                        Color.appField,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(AppPalette.Food.c600.opacity(0.24), lineWidth: 1)
                                    )
                                }
                                .frame(width: 132, alignment: .leading)
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            FoodInputLabel(title: "Calorias", systemImage: "flame.fill")

                            HStack(spacing: 10) {
                                Button {
                                    calories = max(0, calories - 10)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Food.c600)
                                        .frame(width: 28, height: 28)
                                        .background(AppPalette.Food.c600.opacity(0.14), in: Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(calories) kcal")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.appTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Button {
                                    calories = min(4000, calories + 10)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Food.c600)
                                        .frame(width: 28, height: 28)
                                        .background(AppPalette.Food.c600.opacity(0.14), in: Circle())
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
                                    .stroke(AppPalette.Food.c600.opacity(0.24), lineWidth: 1)
                            )

                            FoodInputLabel(title: "Proteina (opcional)", systemImage: "figure.strengthtraining.traditional")

                            HStack(spacing: 10) {
                                Button {
                                    proteinGrams = max(0, proteinGrams - 1)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Food.c600)
                                        .frame(width: 28, height: 28)
                                        .background(AppPalette.Food.c600.opacity(0.14), in: Circle())
                                }
                                .buttonStyle(.plain)

                                Text("\(proteinGrams) g")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.appTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .monospacedDigit()

                                Button {
                                    proteinGrams = min(300, proteinGrams + 1)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppPalette.Food.c600)
                                        .frame(width: 28, height: 28)
                                        .background(AppPalette.Food.c600.opacity(0.14), in: Circle())
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
                                    .stroke(AppPalette.Food.c600.opacity(0.24), lineWidth: 1)
                            )

                            FoodInputLabel(title: "Fecha y hora", systemImage: "calendar")

                            Button {
                                showingDateTimeSheet = true
                            } label: {
                                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Text(dateSummaryText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text(" / ")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                        Text(timeSummaryText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.86)

                                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppPalette.Food.c600.opacity(0.24), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            FoodInputLabel(title: "Nota (opcional)", systemImage: "note.text")

                            TextField("", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($focusedField, equals: .note)
                                .foodInputField(minHeight: 72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.appStrokeSoft, lineWidth: 1)
                        )

                        if isEditing, onDelete != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eliminar alimento")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.18))

                                Button(role: .destructive) {
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Eliminar alimento", systemImage: "trash.fill")
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(isEditing ? "Editar alimento" : "Nuevo alimento")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.Food.c600)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        onSave(name, mealType, quantityForSave, calories, proteinGrams, note, date)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingDateTimeSheet) {
                FoodDateTimePickerSheet(date: $date)
            }
            .alert("Eliminar alimento", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Este alimento se eliminara del registro.")
            }
        }
    }

    init(
        initialDate: Date,
        initialEntry: FoodEntry? = nil,
        onSave: @escaping (_ name: String, _ mealType: FoodMealType, _ quantity: String, _ calories: Int, _ proteinGrams: Int, _ note: String, _ date: Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialEntry != nil

        if let initialEntry {
            let parsedQuantity = Self.parseQuantity(initialEntry.quantity)
            _name = State(initialValue: initialEntry.name)
            _mealType = State(initialValue: initialEntry.mealType)
            _quantityValue = State(initialValue: parsedQuantity.value)
            _quantityUnit = State(initialValue: parsedQuantity.unit)
            _calories = State(initialValue: max(initialEntry.calories, 0))
            _proteinGrams = State(initialValue: Int((initialEntry.proteinGrams ?? 0).rounded()))
            _note = State(initialValue: initialEntry.note)
            _date = State(initialValue: initialEntry.date)
        } else {
            _quantityUnit = State(initialValue: .grams)
            _date = State(initialValue: initialDate)
        }
    }
}

private struct FoodDateTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            ZStack {
                FoodBackgroundView()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fecha")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Divider()
                            .overlay(AppPalette.Food.c600.opacity(0.20))

                        Text("Hora")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)

                        DatePicker(
                            "",
                            selection: $date,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "es_MX"))
                        .frame(width: 220, height: 170)
                        .clipped()
                        .frame(maxWidth: .infinity)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appStrokeSoft, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Fecha y hora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}

private struct FoodInputLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.appTextSecondary)
    }
}

private extension View {
    func foodInputField(minHeight: CGFloat = 0) -> some View {
        self
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                Color.appField,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Food.c600.opacity(0.24), lineWidth: 1)
            )
    }
}
