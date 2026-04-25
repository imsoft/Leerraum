import SwiftUI
import SwiftData
import OSLog

private struct FoodEditTarget: Identifiable {
    let id: UUID
}

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query(
        sort: [
            SortDescriptor(\MealWaterRoutineSlot.sortOrder, order: .forward),
            SortDescriptor(\MealWaterRoutineSlot.hour, order: .forward),
            SortDescriptor(\MealWaterRoutineSlot.minute, order: .forward)
        ]
    )
    private var routineSlots: [MealWaterRoutineSlot]
    @Query(sort: \MealWaterRoutineDayMark.updatedAt, order: .reverse) private var routineMarks: [MealWaterRoutineDayMark]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showingAddSheet = false
    @State private var editTarget: FoodEditTarget?

    private var dayEntries: [FoodEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var mealSections: [(FoodMealType, [FoodEntry])] {
        FoodMealType.allCases.compactMap { type in
            let grouped = dayEntries.filter { $0.mealType == type }
            return grouped.isEmpty ? nil : (type, grouped)
        }
    }

    private func qualityCount(for quality: FoodQualityType) -> Int {
        dayEntries.filter { $0.quality == quality }.count
    }

    private var routineDayStart: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    private var routineDoneBySlotId: [UUID: Bool] {
        let cal = Calendar.current
        var map: [UUID: Bool] = [:]
        for mark in routineMarks where cal.isDate(mark.dayStart, inSameDayAs: routineDayStart) {
            map[mark.slotId] = mark.isDone
        }
        return map
    }

    private var enabledRoutineSlots: [MealWaterRoutineSlot] {
        routineSlots.filter(\.isEnabled)
    }

    private var calendarSummaryText: String {
        let day = progressSnapshot(for: selectedDate)
        return "Comidas \(day.doneMeals)/\(day.totalMeals) · Agua \(day.doneWater)/\(day.totalWater)"
    }

    private var selectedDayProgress: DayRoutineProgress {
        progressSnapshot(for: selectedDate)
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
                            healthyCount: qualityCount(for: .healthy),
                            mediumCount: qualityCount(for: .medium),
                            junkCount: qualityCount(for: .junk)
                        )

                        FoodProgressCalendarCard(
                            displayedMonth: $displayedMonth,
                            selectedDate: $selectedDate,
                            subtitle: calendarSummaryText,
                            progressForDay: { day in
                                progressSnapshot(for: day).totalProgress
                            }
                        )

                        if !enabledRoutineSlots.isEmpty {
                            FoodRoutineScheduleCard(
                                dayStart: routineDayStart,
                                slots: enabledRoutineSlots,
                                doneBySlotId: routineDoneBySlotId,
                                onToggle: { slot, isDone in
                                    setRoutineMark(slot: slot, isDone: isDone)
                                }
                            )
                        }

                        FoodSelectedDayOverviewCard(
                            selectedDate: selectedDate,
                            foodCount: dayEntries.count,
                            doneMeals: selectedDayProgress.doneMeals,
                            totalMeals: selectedDayProgress.totalMeals,
                            doneWater: selectedDayProgress.doneWater,
                            totalWater: selectedDayProgress.totalWater
                        )

                        FeatureSectionHeader(title: "Alimentos del dia") {
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
                AddFoodEntryView(initialDate: selectedDate) { name, mealType, quality, note, date in
                    createEntry(
                        name: name,
                        mealType: mealType,
                        quality: quality,
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
                    ) { name, mealType, quality, note, date in
                        updateEntry(
                            selectedEntryForEditing,
                            name: name,
                            mealType: mealType,
                            quality: quality,
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
                RoutineSlotSeeder.ensureDefaultRoutineSlotsIfNeeded(in: modelContext)
                displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
            }
        }
    }

    private func progressSnapshot(for day: Date) -> DayRoutineProgress {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let doneSlotIds = Set(
            routineMarks
                .filter { $0.isDone && cal.isDate($0.dayStart, inSameDayAs: dayStart) }
                .map(\.slotId)
        )

        let mealSlots = enabledRoutineSlots.filter { !$0.isWater }
        let waterSlots = enabledRoutineSlots.filter(\.isWater)

        let doneMeals = mealSlots.reduce(into: 0) { partialResult, slot in
            if doneSlotIds.contains(slot.id) { partialResult += 1 }
        }
        let doneWater = waterSlots.reduce(into: 0) { partialResult, slot in
            if doneSlotIds.contains(slot.id) { partialResult += 1 }
        }

        let totalMeals = mealSlots.count
        let totalWater = waterSlots.count
        let totalDone = doneMeals + doneWater
        let totalTracked = max(1, totalMeals + totalWater)

        return DayRoutineProgress(
            doneMeals: doneMeals,
            totalMeals: totalMeals,
            doneWater: doneWater,
            totalWater: totalWater,
            totalProgress: Double(totalDone) / Double(totalTracked)
        )
    }

    private func setRoutineMark(slot: MealWaterRoutineSlot, isDone: Bool) {
        let cal = Calendar.current
        let dayStart = routineDayStart
        if let existing = routineMarks.first(where: {
            $0.slotId == slot.id && cal.isDate($0.dayStart, inSameDayAs: dayStart)
        }) {
            existing.isDone = isDone
            existing.updatedAt = .now
        } else {
            modelContext.insert(MealWaterRoutineDayMark(slotId: slot.id, dayStart: dayStart, isDone: isDone))
        }
        NotificationCenter.default.post(name: .leerraumRefreshWidgetSnapshot, object: nil)
    }

    private func createEntry(
        name: String,
        mealType: FoodMealType,
        quality: FoodQualityType,
        note: String,
        date: Date
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let entry = FoodEntry(
            name: trimmedName,
            mealType: mealType,
            quality: quality,
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
        quality: FoodQualityType,
        note: String,
        date: Date
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            entry.name = trimmedName
            entry.mealType = mealType
            entry.quantity = ""
            entry.quality = quality
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

private struct DayRoutineProgress {
    let doneMeals: Int
    let totalMeals: Int
    let doneWater: Int
    let totalWater: Int
    let totalProgress: Double
}

private struct FoodSelectedDayOverviewCard: View {
    let selectedDate: Date
    let foodCount: Int
    let doneMeals: Int
    let totalMeals: Int
    let doneWater: Int
    let totalWater: Int

    private var dateText: String {
        AppDateFormatters.esMXLongWeekdayDayMonth.string(from: selectedDate).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dia seleccionado")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

            Text(dateText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            HStack(spacing: 8) {
                dayPill("Comi", "\(foodCount)")
                dayPill("Rutina comida", "\(doneMeals)/\(totalMeals)")
                dayPill("Agua", "\(doneWater)/\(totalWater)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }

    private func dayPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.appTextSecondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appField, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    let healthyCount: Int
    let mediumCount: Int
    let junkCount: Int

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
                FoodMetricPill(title: "Saludable", value: "\(healthyCount)")
                FoodMetricPill(title: "Medio", value: "\(mediumCount)")
                FoodMetricPill(title: "Chatarra", value: "\(junkCount)")
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

private struct FoodProgressCalendarCard: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let subtitle: String
    let progressForDay: (Date) -> Double

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["L", "M", "M", "J", "V", "S", "D"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var dayCells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells = Array<Date?>(repeating: nil, count: leading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        return cells
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Calendario de progreso", systemImage: "calendar")
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                monthSwitchButton(systemImage: "chevron.left", delta: -1)
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(minWidth: 120)
                monthSwitchButton(systemImage: "chevron.right", delta: 1)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, dayLabel in
                    Text(dayLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear
                            .frame(height: 28)
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

    private func monthSwitchButton(systemImage: String, delta: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            }
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 22, height: 22)
                .background(Color.appField, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ day: Date) -> some View {
        let progress = progressForDay(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = day
            }
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(progressTint(for: progress).opacity(isSelected ? 0.34 : 0.20))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? AppPalette.Food.c600 : (isToday ? AppPalette.Food.c600.opacity(0.45) : .clear), lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func progressTint(for progress: Double) -> Color {
        switch progress {
        case 0.80...:
            return Color(red: 0.20, green: 0.72, blue: 0.45)
        case 0.40...:
            return Color(red: 0.95, green: 0.62, blue: 0.22)
        case 0.01...:
            return Color(red: 0.91, green: 0.39, blue: 0.35)
        default:
            return Color.appField
        }
    }
}

private struct FoodRoutineScheduleCard: View {
    let dayStart: Date
    let slots: [MealWaterRoutineSlot]
    let doneBySlotId: [UUID: Bool]
    let onToggle: (MealWaterRoutineSlot, Bool) -> Void

    private var mealSlots: [MealWaterRoutineSlot] {
        slots.filter { !$0.isWater }
    }

    private var waterSlots: [MealWaterRoutineSlot] {
        slots.filter(\.isWater)
    }

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(dayStart) {
            return "Horarios de hoy"
        }
        return "Horarios del " + AppDateFormatters.esMXShortDate.string(from: dayStart).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(dayTitle, systemImage: "clock.fill")
                .font(.headline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text("Toca una tarjeta para marcarla como cumplida.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)

            if !mealSlots.isEmpty {
                routineSection(title: "Comidas", icon: "fork.knife", sectionSlots: mealSlots)
            }

            if !waterSlots.isEmpty {
                routineSection(title: "Agua", icon: "drop.fill", sectionSlots: waterSlots)
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

    @ViewBuilder
    private func routineSection(title: String, icon: String, sectionSlots: [MealWaterRoutineSlot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sectionSlots, id: \.id) { slot in
                        routineCard(slot)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 1)
            }
        }
    }

    private func routineCard(_ slot: MealWaterRoutineSlot) -> some View {
        let done = doneBySlotId[slot.id] ?? false
        return Button {
            onToggle(slot, !done)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: slot.isWater ? "drop.fill" : "fork.knife")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(slot.isWater ? Color(red: 0.20, green: 0.55, blue: 0.85) : AppPalette.Food.c600)
                    Text(slot.timeString)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.appTextSecondary)
                }

                Text(slot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(done ? Color(red: 0.20, green: 0.72, blue: 0.45) : Color.appTextSecondary)
                    Text(done ? "Cumplido" : "Pendiente")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(done ? Color(red: 0.20, green: 0.62, blue: 0.40) : Color.appTextSecondary)
                }
            }
            .padding(12)
            .frame(width: 132, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(done ? Color(red: 0.89, green: 0.97, blue: 0.92) : Color.appField)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(done ? Color(red: 0.20, green: 0.72, blue: 0.45).opacity(0.35) : Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(mealType.displayName, systemImage: mealType.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(mealType.tint)

                Spacer()
                Text("\(entries.count) alimento(s)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
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

                    Text(timeText)
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

                HStack(spacing: 8) {
                    FoodQualityBadge(quality: entry.quality)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }
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

private struct FoodQualityBadge: View {
    let quality: FoodQualityType

    var body: some View {
        Label(quality.displayName, systemImage: quality.icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(quality.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(quality.tint.opacity(0.15), in: Capsule())
    }
}

private struct AddFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mealType: FoodMealType = .breakfast
    @State private var quality: FoodQualityType = .medium
    @State private var note = ""
    @State private var date: Date
    @State private var showingDeleteAlert = false
    @State private var showingDateTimeSheet = false
    @FocusState private var focusedField: FoodField?

    private let isEditing: Bool
    let onSave: (_ name: String, _ mealType: FoodMealType, _ quality: FoodQualityType, _ note: String, _ date: Date) -> Void
    let onDelete: (() -> Void)?

    private enum FoodField {
        case name
        case note
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                            FoodInputLabel(title: "Calidad de la comida", systemImage: quality.icon)

                            HStack(spacing: 8) {
                                ForEach(FoodQualityType.allCases) { option in
                                    Button {
                                        quality = option
                                    } label: {
                                        Text(option.displayName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(quality == option ? .white : option.tint)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                (quality == option ? option.tint : option.tint.opacity(0.12)),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

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
                        onSave(name, mealType, quality, note, date)
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
        onSave: @escaping (_ name: String, _ mealType: FoodMealType, _ quality: FoodQualityType, _ note: String, _ date: Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onDelete = onDelete
        self.isEditing = initialEntry != nil

        if let initialEntry {
            _name = State(initialValue: initialEntry.name)
            _mealType = State(initialValue: initialEntry.mealType)
            _quality = State(initialValue: initialEntry.quality)
            _note = State(initialValue: initialEntry.note)
            _date = State(initialValue: initialEntry.date)
        } else {
            _quality = State(initialValue: .medium)
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
