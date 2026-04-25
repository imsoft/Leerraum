import Foundation

/// Enlaces `leerraum://...` usados por widgets (y opcionalmente por otras entradas).
enum LeerraumDeepLink: Equatable, CustomStringConvertible {
    var description: String {
        switch self {
        case .finance: return "finance"
        case .gym: return "gym"
        case .food: return "food"
        case .quotes: return "quotes"
        case .lifeGoals: return "lifeGoals"
        case .home: return "home"
        }
    }

    case finance
    case gym
    case food
    case quotes
    case lifeGoals

    /// Abre la app en la pestaña principal (resumen Leerraum).
    case home

    init?(url: URL) {
        guard url.scheme?.lowercased() == "leerraum" else { return nil }

        let host = (url.host ?? "").lowercased()
        let firstPath = url.pathComponents.dropFirst().first?.lowercased()

        let token: String
        if !host.isEmpty, host != "/" {
            token = host
        } else if let firstPath, !firstPath.isEmpty {
            token = firstPath
        } else {
            self = .home
            return
        }

        switch token {
        case "finance", "finanzas":
            self = .finance
        case "gym":
            self = .gym
        case "food", "comidas", "comida":
            self = .food
        case "quotes", "frases", "frase":
            self = .quotes
        case "lifegoals", "life-goals", "metas", "metasdevida":
            self = .lifeGoals
        case "home", "inicio":
            self = .home
        default:
            return nil
        }
    }

    var url: URL {
        let path: String
        switch self {
        case .finance:
            path = "finance"
        case .gym:
            path = "gym"
        case .food:
            path = "food"
        case .quotes:
            path = "quotes"
        case .lifeGoals:
            path = "lifegoals"
        case .home:
            path = "home"
        }
        return URL(string: "leerraum://\(path)")!
    }
}
