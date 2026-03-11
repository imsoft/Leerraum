import SwiftUI

enum AppStorageKey {
    static let themeMode = "app.theme.mode"
    static let exchangeRateProvider = "finance.exchange.provider"
    static let banxicoToken = "finance.exchange.banxico.token"
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Sistema"
        case .light:
            return "Claro"
        case .dark:
            return "Oscuro"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum ExchangeRateProviderPreference: String, CaseIterable, Identifiable {
    case automatic
    case banxico
    case openERAPI
    case frankfurter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "Automatico"
        case .banxico:
            return "Banxico (oficial)"
        case .openERAPI:
            return "OpenERAPI"
        case .frankfurter:
            return "Frankfurter"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic:
            return "Usa Banxico si hay token; si no, usa proveedores publicos."
        case .banxico:
            return "Requiere token SIE de Banxico."
        case .openERAPI:
            return "Proveedor publico con tasa de mercado."
        case .frankfurter:
            return "Proveedor publico alternativo."
        }
    }
}
