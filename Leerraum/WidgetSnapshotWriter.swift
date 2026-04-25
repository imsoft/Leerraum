import Foundation
import SwiftData
import WidgetKit

enum WidgetSnapshotWriter {
    static func refresh(
        foodEntries: [FoodEntry],
        quotes: [QuoteMessage],
        lifeGoals: [LifeGoal],
        routineSlots: [MealWaterRoutineSlot],
        routineMarks: [MealWaterRoutineDayMark]
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayFood = foodEntries.filter { calendar.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date > $1.date }

        let healthy = todayFood.filter { $0.quality == .healthy }.count
        let medium = todayFood.filter { $0.quality == .medium }.count
        let junk = todayFood.filter { $0.quality == .junk }.count

        let previewLines: [String] = todayFood.prefix(3).map { entry in
            "\(entry.mealType.displayName) · \(entry.name)"
        }

        let activeQuotes = quotes.filter {
            $0.isActive && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let quote = activeQuotes.randomElement()
        let quoteText = quote?.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let quoteAuthor = quote?.author.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let pendingGoals = lifeGoals.filter {
            $0.progress < 100 && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let goal = pendingGoals.randomElement() ?? lifeGoals.first { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let goalTitle = goal?.title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let goalProgress = goal.map { max(0, min($0.progress, 100)) } ?? 0
        let goalArea = goal?.area.displayName ?? ""

        let routineRows = buildRoutineRows(
            slots: routineSlots,
            marks: routineMarks,
            calendar: calendar,
            todayStart: today
        )

        let payload = WidgetSnapshotPayload(
            updatedAt: Date(),
            foodTotalToday: todayFood.count,
            foodHealthyToday: healthy,
            foodMediumToday: medium,
            foodJunkToday: junk,
            foodPreviewLines: previewLines,
            quoteText: quoteText,
            quoteAuthor: quoteAuthor,
            lifeGoalTitle: goalTitle,
            lifeGoalProgress: goalProgress,
            lifeGoalAreaDisplayName: goalArea,
            routineRows: routineRows
        )

        guard let defaults = UserDefaults(suiteName: LeerraumAppGroup.identifier),
              let data = try? JSONEncoder().encode(payload) else {
            return
        }
        defaults.set(data, forKey: WidgetSnapshotPayload.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func buildRoutineRows(
        slots: [MealWaterRoutineSlot],
        marks: [MealWaterRoutineDayMark],
        calendar: Calendar,
        todayStart: Date
    ) -> [RoutineSlotRowPayload] {
        let marksToday = marks.filter { calendar.isDate($0.dayStart, inSameDayAs: todayStart) }
        var doneBySlot: [UUID: Bool] = [:]
        for mark in marksToday {
            doneBySlot[mark.slotId] = mark.isDone
        }

        return slots
            .filter(\.isEnabled)
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
                return lhs.minute < rhs.minute
            }
            .map { slot in
                RoutineSlotRowPayload(
                    id: slot.id.uuidString,
                    title: slot.title,
                    timeText: slot.timeString,
                    isWater: slot.isWater,
                    isDone: doneBySlot[slot.id] ?? false
                )
            }
    }
}
