import Foundation

/// Fila de horario de comida o agua para el widget de rutina.
struct RoutineSlotRowPayload: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var timeText: String
    var isWater: Bool
    var isDone: Bool
}

/// Datos serializados que la app escribe y los widgets leen (UserDefaults + App Group).
struct WidgetSnapshotPayload: Codable, Equatable {
    static let storageKey = "leerraum.widgetSnapshot.v2"

    var updatedAt: Date

    var foodTotalToday: Int
    var foodHealthyToday: Int
    var foodMediumToday: Int
    var foodJunkToday: Int
    /// Hasta 3 lineas cortas, ej. "Desayuno · Avena"
    var foodPreviewLines: [String]

    var quoteText: String
    var quoteAuthor: String

    var lifeGoalTitle: String
    var lifeGoalProgress: Int
    var lifeGoalAreaDisplayName: String

    /// Horarios de comida / agua y si se marcaron hoy en la app.
    var routineRows: [RoutineSlotRowPayload]

    static let empty = WidgetSnapshotPayload(
        updatedAt: .distantPast,
        foodTotalToday: 0,
        foodHealthyToday: 0,
        foodMediumToday: 0,
        foodJunkToday: 0,
        foodPreviewLines: [],
        quoteText: "",
        quoteAuthor: "",
        lifeGoalTitle: "",
        lifeGoalProgress: 0,
        lifeGoalAreaDisplayName: "",
        routineRows: []
    )

    static func load() -> WidgetSnapshotPayload {
        guard let data = UserDefaults(suiteName: LeerraumAppGroup.identifier)?.data(forKey: storageKey) else {
            return .empty
        }
        return (try? JSONDecoder().decode(WidgetSnapshotPayload.self, from: data)) ?? .empty
    }
}
