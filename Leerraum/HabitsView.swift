import SwiftUI
import SwiftData

private enum HabitDailyStatus {
    case completed
    case missed

    var title: String {
        switch self {
        case .completed:
            return "Cumplido"
        case .missed:
            return "No cumplido"
        }
    }

    var icon: String {
        switch self {
        case .completed:
            return "checkmark"
        case .missed:
            return "xmark"
        }
    }

    var tint: Color {
        switch self {
        case .completed:
            return AppPalette.Habits.c600
        case .missed:
            return Color.financeExpenseAccent
        }
    }
}

private struct HabitEditTarget: Identifiable {
    let id: UUID
}

private struct HabitCalendarTarget: Identifiable {
    let id: UUID
}

private struct HabitPayload {
    let title: String
    let note: String
    let reminderDate: Date
    let isActive: Bool
}

private enum HabitDefaults {
    static var reminderDate: Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 21
        components.minute = 0
        return calendar.date(from: components) ?? now
    }
}

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt, order: .reverse) private var habits: [Habit]

    @State private var showingAddSheet = false
    @State private var editTarget: HabitEditTarget?
    @State private var calendarTarget: HabitCalendarTarget?

    private let calendar = Calendar.current

    private var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    private var completedTodayCount: Int {
        activeHabits.reduce(0) { partial, habit in
            partial + (statusForDate(habit, on: .now) == .completed ? 1 : 0)
        }
    }

    private var missedTodayCount: Int {
        activeHabits.reduce(0) { partial, habit in
            partial + (statusForDate(habit, on: .now) == .missed ? 1 : 0)
        }
    }

    private var pendingTodayCount: Int {
        max(activeHabits.count - completedTodayCount - missedTodayCount, 0)
    }

    private var completionRateToday: Int {
        guard !activeHabits.isEmpty else { return 0 }
        return Int((Double(completedTodayCount) / Double(activeHabits.count) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        HabitsSummaryCard(
                            totalHabits: habits.count,
                            activeHabits: activeHabits.count,
                            completedToday: completedTodayCount,
                            pendingToday: pendingTodayCount,
                            completionRate: completionRateToday
                        )

                        FeatureSectionHeader(title: "Tus habitos") {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Nuevo", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppPalette.Habits.c600)
                        }

                        if habits.isEmpty {
                            HabitsEmptyStateCard {
                                showingAddSheet = true
                            }
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(habits, id: \.id) { habit in
                                    HabitRow(
                                        habit: habit,
                                        todayStatus: statusForDate(habit, on: .now),
                                        onMarkCompleted: {
                                            setStatus(.completed, for: habit, on: .now)
                                        },
                                        onMarkMissed: {
                                            setStatus(.missed, for: habit, on: .now)
                                        },
                                        onOpenCalendar: {
                                            calendarTarget = HabitCalendarTarget(id: habit.id)
                                        },
                                        onEditTap: {
                                            editTarget = HabitEditTarget(id: habit.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Habitos")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSheet) {
                AddHabitView { payload in
                    createHabit(payload)
                }
            }
            .sheet(item: $editTarget) { target in
                if let selectedHabit = habits.first(where: { $0.id == target.id }) {
                    AddHabitView(initialHabit: selectedHabit) { payload in
                        updateHabit(selectedHabit, payload: payload)
                    } onDelete: {
                        deleteHabit(selectedHabit)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Habito no disponible",
                            systemImage: "checklist",
                            description: Text("Este registro ya no existe.")
                        )
                    }
                }
            }
            .sheet(item: $calendarTarget) { target in
                if let selectedHabit = habits.first(where: { $0.id == target.id }) {
                    HabitCalendarView(habit: selectedHabit) { date in
                        statusForDate(selectedHabit, on: date)
                    }
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Calendario no disponible",
                            systemImage: "calendar",
                            description: Text("Este habito ya no existe.")
                        )
                    }
                }
            }
        }
    }

    private func createHabit(_ payload: HabitPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: payload.reminderDate)
        let newHabit = Habit(
            title: title,
            note: payload.note.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderHour: timeComponents.hour ?? 21,
            reminderMinute: timeComponents.minute ?? 0,
            isActive: payload.isActive
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(newHabit)
        }
    }

    private func updateHabit(_ habit: Habit, payload: HabitPayload) {
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: payload.reminderDate)
        withAnimation(.easeInOut(duration: 0.2)) {
            habit.title = title
            habit.note = payload.note.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.reminderHour = max(0, min(timeComponents.hour ?? 21, 23))
            habit.reminderMinute = max(0, min(timeComponents.minute ?? 0, 59))
            habit.isActive = payload.isActive
        }
    }

    private func deleteHabit(_ habit: Habit) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(habit)
        }
    }

    private func setStatus(_ status: HabitDailyStatus, for habit: Habit, on date: Date) {
        let targetDate = calendar.startOfDay(for: date)
        let didComplete = status == .completed

        withAnimation(.easeInOut(duration: 0.2)) {
            if let existingEntry = entry(for: habit, on: targetDate) {
                existingEntry.didComplete = didComplete
            } else {
                let newEntry = HabitEntry(
                    date: targetDate,
                    didComplete: didComplete,
                    habit: habit
                )
                modelContext.insert(newEntry)
            }
        }
    }

    private func statusForDate(_ habit: Habit, on date: Date) -> HabitDailyStatus? {
        guard let currentEntry = entry(for: habit, on: date) else { return nil }
        return currentEntry.didComplete ? .completed : .missed
    }

    private func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        let targetDate = calendar.startOfDay(for: date)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
        let habitID = habit.persistentModelID
        var descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate<HabitEntry> {
                $0.habit?.persistentModelID == habitID &&
                $0.date >= targetDate &&
                $0.date < nextDate
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

private struct HabitsBackgroundView: View {
    var body: some View {
        FeatureGradientBackground(palette: .habits)
    }
}

private struct HabitsSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let totalHabits: Int
    let activeHabits: Int
    let completedToday: Int
    let pendingToday: Int
    let completionRate: Int

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Habits.c900, AppPalette.Habits.c700]
        }
        return [AppPalette.Habits.c700, AppPalette.Habits.c500]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Constancia diaria")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(.white.opacity(0.95))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(completionRate)%")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("hoy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            HStack(spacing: 8) {
                HabitsSummaryPill(title: "Habitos", value: "\(totalHabits)")
                HabitsSummaryPill(title: "Activos", value: "\(activeHabits)")
                HabitsSummaryPill(title: "Cumplidos", value: "\(completedToday)")
                HabitsSummaryPill(title: "Pendientes", value: "\(pendingToday)")
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
                .stroke(.white.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 1)
        )
    }
}

private struct HabitsSummaryPill: View {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            .white.opacity(colorScheme == .dark ? 0.18 : 0.24),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct HabitsEmptyStateCard: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sin habitos todavia")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Agrega habitos diarios para registrar si los cumpliste o no y ver tu progreso en calendario.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Crear habito") {
                onCreateTap()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.Habits.c600)
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

private struct HabitRow: View {
    let habit: Habit
    let todayStatus: HabitDailyStatus?
    let onMarkCompleted: () -> Void
    let onMarkMissed: () -> Void
    let onOpenCalendar: () -> Void
    let onEditTap: () -> Void

    private var reminderText: String {
        habit.reminderDate.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .hour()
                .minute()
        )
    }

    private var statusText: String {
        switch todayStatus {
        case .completed:
            return "Hoy: cumplido"
        case .missed:
            return "Hoy: no cumplido"
        case nil:
            return "Hoy: sin registro"
        }
    }

    private var statusTint: Color {
        todayStatus?.tint ?? Color.appTextSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(2)

                    if !habit.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(habit.note)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    onEditTap()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.Habits.c700)
                        .frame(width: 30, height: 30)
                        .background(AppPalette.Habits.c200.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Label(reminderText, systemImage: "bell.badge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.Habits.c700)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppPalette.Habits.c200.opacity(0.38), in: Capsule())

                if !habit.isActive {
                    Text("Pausado")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.appBackgroundSecondary, in: Capsule())
                }

                Spacer(minLength: 8)

                Button("Calendario") {
                    onOpenCalendar()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(AppPalette.Habits.c600)
            }

            HStack(spacing: 8) {
                HabitMarkButton(
                    title: "Si",
                    icon: "checkmark",
                    isSelected: todayStatus == .completed,
                    tint: AppPalette.Habits.c600,
                    onTap: onMarkCompleted
                )

                HabitMarkButton(
                    title: "No",
                    icon: "xmark",
                    isSelected: todayStatus == .missed,
                    tint: Color.financeExpenseAccent,
                    onTap: onMarkMissed
                )
            }

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            Color.appField,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct HabitMarkButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : tint)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? tint : tint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.0 : 0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialHabit: Habit?
    private let onSave: (HabitPayload) -> Void
    private let onDelete: (() -> Void)?

    @State private var title: String
    @State private var note: String
    @State private var reminderDate: Date
    @State private var isActive: Bool

    init(
        initialHabit: Habit? = nil,
        onSave: @escaping (HabitPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialHabit = initialHabit
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: initialHabit?.title ?? "")
        _note = State(initialValue: initialHabit?.note ?? "")
        _reminderDate = State(initialValue: initialHabit?.reminderDate ?? HabitDefaults.reminderDate)
        _isActive = State(initialValue: initialHabit?.isActive ?? true)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var screenTitle: String {
        initialHabit == nil ? "Nuevo habito" : "Editar habito"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitsBackgroundView()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HabitsFormCard(title: "Nombre", icon: "checkmark.circle") {
                            TextField("Ej. Tomar agua", text: $title)
                                .font(.body)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                                )
                        }

                        HabitsFormCard(title: "Nota (opcional)", icon: "note.text") {
                            TextField("Detalles del habito", text: $note, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .font(.body)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(
                                    Color.appField,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                                )
                        }

                        HabitsFormCard(title: "Recordatorio diario", icon: "bell.badge") {
                            DatePicker(
                                "Hora",
                                selection: $reminderDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.appStrokeSoft, lineWidth: 1)
                            )
                        }

                        HabitsFormCard(title: "Estado", icon: "power") {
                            Toggle(isOn: $isActive) {
                                Text("Habito activo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                            }
                            .tint(AppPalette.Habits.c600)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(
                                Color.appField,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.appStrokeSoft, lineWidth: 1)
                            )
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                onDelete?()
                                dismiss()
                            } label: {
                                Label("Eliminar habito", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.financeExpenseAccent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(
                            HabitPayload(
                                title: title,
                                note: note,
                                reminderDate: reminderDate,
                                isActive: isActive
                            )
                        )
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct HabitsFormCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct HabitCalendarView: View {
    let habit: Habit
    let statusForDate: (Date) -> HabitDailyStatus?

    @State private var visibleMonth: Date
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(habit: Habit, statusForDate: @escaping (Date) -> HabitDailyStatus?) {
        self.habit = habit
        self.statusForDate = statusForDate
        _visibleMonth = State(initialValue: HabitCalendarMath.startOfMonth(for: .now))
    }

    private var monthTitle: String {
        visibleMonth.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .month(.wide)
                .year()
        )
        .capitalized
    }

    private var monthDays: [Date?] {
        HabitCalendarMath.monthGridDates(for: visibleMonth, calendar: calendar)
    }

    private var weekdaySymbols: [String] {
        HabitCalendarMath.weekdaySymbols(
            calendar: calendar,
            locale: Locale(identifier: "es_MX")
        )
    }

    private var monthCompletedCount: Int {
        monthDays.compactMap { $0 }.reduce(0) { partial, date in
            partial + (statusForDate(date) == .completed ? 1 : 0)
        }
    }

    private var monthMissedCount: Int {
        monthDays.compactMap { $0 }.reduce(0) { partial, date in
            partial + (statusForDate(date) == .missed ? 1 : 0)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HabitsBackgroundView()
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(2)
                        Text("Progreso por calendario")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            moveMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppPalette.Habits.c700)
                                .frame(width: 34, height: 34)
                                .background(AppPalette.Habits.c200.opacity(0.45), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Text(monthTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(maxWidth: .infinity)

                        Button {
                            moveMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppPalette.Habits.c700)
                                .frame(width: 34, height: 34)
                                .background(AppPalette.Habits.c200.opacity(0.45), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 8) {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(monthDays.indices, id: \.self) { index in
                                let date = monthDays[index]
                                HabitCalendarDayCell(
                                    date: date,
                                    status: date.map(statusForDate) ?? nil,
                                    isToday: date.map { calendar.isDateInToday($0) } ?? false,
                                    isFuture: date.map { calendar.startOfDay(for: $0) > calendar.startOfDay(for: .now) } ?? false,
                                    isDarkMode: colorScheme == .dark
                                )
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.appStrokeSoft, lineWidth: 1)
                    )

                    HStack(spacing: 8) {
                        HabitCalendarLegendItem(
                            title: "Cumplido",
                            color: AppPalette.Habits.c600
                        )
                        HabitCalendarLegendItem(
                            title: "No cumplido",
                            color: Color.financeExpenseAccent.opacity(0.65)
                        )
                        HabitCalendarLegendItem(
                            title: "Sin registro",
                            color: Color.appField
                        )
                    }

                    HStack(spacing: 8) {
                        HabitCalendarMetricCard(
                            title: "Cumplidos",
                            value: "\(monthCompletedCount)",
                            tint: AppPalette.Habits.c700
                        )
                        HabitCalendarMetricCard(
                            title: "No cumplidos",
                            value: "\(monthMissedCount)",
                            tint: Color.financeExpenseAccent
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func moveMonth(by value: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = HabitCalendarMath.startOfMonth(for: newDate, calendar: calendar)
        }
    }
}

private struct HabitCalendarLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

private struct HabitCalendarMetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 1)
        )
    }
}

private struct HabitCalendarDayCell: View {
    let date: Date?
    let status: HabitDailyStatus?
    let isToday: Bool
    let isFuture: Bool
    let isDarkMode: Bool

    private var backgroundColor: Color {
        if let status {
            switch status {
            case .completed:
                return status.tint
            case .missed:
                return status.tint.opacity(isDarkMode ? 0.50 : 0.22)
            }
        }

        if isFuture {
            return Color.appBackgroundSecondary.opacity(isDarkMode ? 0.45 : 0.72)
        }

        return Color.appField
    }

    private var textColor: Color {
        if let status {
            switch status {
            case .completed:
                return .white
            case .missed:
                return Color.financeExpenseAccent
            }
        }

        return Color.appTextPrimary
    }

    var body: some View {
        Group {
            if let date {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(isToday ? .bold : .semibold))
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(
                        backgroundColor,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isToday ? AppPalette.Habits.c500 : Color.clear,
                                lineWidth: isToday ? 1.5 : 0
                            )
                    )
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
        }
    }
}

private enum HabitCalendarMath {
    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func monthGridDates(for monthDate: Date, calendar: Calendar = .current) -> [Date?] {
        let startOfMonth = startOfMonth(for: monthDate, calendar: calendar)
        guard let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingCount)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    static func weekdaySymbols(calendar: Calendar = .current, locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else {
            return ["D", "L", "M", "M", "J", "V", "S"]
        }

        let firstIndex = max(0, min(calendar.firstWeekday - 1, 6))
        let head = symbols[firstIndex...]
        let tail = symbols[..<firstIndex]
        let rotated = Array(head + tail)
        return rotated.map { String($0.prefix(1)).uppercased() }
    }
}
