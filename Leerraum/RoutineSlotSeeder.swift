import SwiftData

enum RoutineSlotSeeder {
    @MainActor
    static func ensureDefaultRoutineSlotsIfNeeded(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<MealWaterRoutineSlot>()
        let existingSlots = (try? modelContext.fetch(descriptor)) ?? []

        let defaults: [(String, Int, Int, Bool, Int)] = [
            ("Desayuno", 8, 0, false, 0),
            ("Snack", 11, 0, false, 1),
            ("Comida", 14, 0, false, 2),
            ("Snack", 17, 0, false, 3),
            ("Cena", 20, 0, false, 4),
            ("Agua", 9, 0, true, 10),
            ("Agua", 11, 0, true, 11),
            ("Agua", 13, 0, true, 12),
            ("Agua", 15, 30, true, 13),
            ("Agua", 17, 30, true, 14),
            ("Agua", 19, 0, true, 15),
            ("Agua", 21, 0, true, 16)
        ]

        for row in defaults {
            let alreadyExists = existingSlots.contains {
                $0.title == row.0 &&
                $0.hour == row.1 &&
                $0.minute == row.2 &&
                $0.isWater == row.3
            }
            if alreadyExists { continue }

            let slot = MealWaterRoutineSlot(
                title: row.0,
                hour: row.1,
                minute: row.2,
                isWater: row.3,
                sortOrder: row.4
            )
            modelContext.insert(slot)
        }
    }
}
