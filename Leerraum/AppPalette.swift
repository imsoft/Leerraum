import SwiftUI

enum AppPalette {
    enum Red {
        static let c50 = Color(hex: "#FEF2F2")
        static let c100 = Color(hex: "#FEE2E2")
        static let c200 = Color(hex: "#FECACA")
        static let c300 = Color(hex: "#FCA5A5")
        static let c400 = Color(hex: "#F87171")
        static let c500 = Color(hex: "#EF4444")
        static let c600 = Color(hex: "#DC2626")
        static let c700 = Color(hex: "#B91C1C")
        static let c800 = Color(hex: "#991B1B")
        static let c900 = Color(hex: "#7F1D1D")
        static let c950 = Color(hex: "#450A0A")
    }

    enum Orange {
        static let c50 = Color(hex: "#FFF7ED")
        static let c100 = Color(hex: "#FFEDD5")
        static let c200 = Color(hex: "#FED7AA")
        static let c300 = Color(hex: "#FDBA74")
        static let c400 = Color(hex: "#FB923C")
        static let c500 = Color(hex: "#F97316")
        static let c600 = Color(hex: "#EA580C")
        static let c700 = Color(hex: "#C2410C")
        static let c800 = Color(hex: "#9A3412")
        static let c900 = Color(hex: "#7C2D12")
        static let c950 = Color(hex: "#431407")
    }

    enum Amber {
        static let c50 = Color(hex: "#FFFBEB")
        static let c100 = Color(hex: "#FEF3C7")
        static let c200 = Color(hex: "#FDE68A")
        static let c300 = Color(hex: "#FCD34D")
        static let c400 = Color(hex: "#FBBF24")
        static let c500 = Color(hex: "#F59E0B")
        static let c600 = Color(hex: "#D97706")
        static let c700 = Color(hex: "#B45309")
        static let c800 = Color(hex: "#92400E")
        static let c900 = Color(hex: "#78350F")
        static let c950 = Color(hex: "#451A03")
    }

    enum Yellow {
        static let c50 = Color(hex: "#FEFCE8")
        static let c100 = Color(hex: "#FEF9C3")
        static let c200 = Color(hex: "#FEF08A")
        static let c300 = Color(hex: "#FDE047")
        static let c400 = Color(hex: "#FACC15")
        static let c500 = Color(hex: "#EAB308")
        static let c600 = Color(hex: "#CA8A04")
        static let c700 = Color(hex: "#A16207")
        static let c800 = Color(hex: "#854D0E")
        static let c900 = Color(hex: "#713F12")
        static let c950 = Color(hex: "#422006")
    }

    enum Lime {
        static let c50 = Color(hex: "#F7FEE7")
        static let c100 = Color(hex: "#ECFCCB")
        static let c200 = Color(hex: "#D9F99D")
        static let c300 = Color(hex: "#BEF264")
        static let c400 = Color(hex: "#A3E635")
        static let c500 = Color(hex: "#84CC16")
        static let c600 = Color(hex: "#65A30D")
        static let c700 = Color(hex: "#4D7C0F")
        static let c800 = Color(hex: "#3F6212")
        static let c900 = Color(hex: "#365314")
        static let c950 = Color(hex: "#1A2E05")
    }

    enum Green {
        static let c50 = Color(hex: "#F0FDF4")
        static let c100 = Color(hex: "#DCFCE7")
        static let c200 = Color(hex: "#BBF7D0")
        static let c300 = Color(hex: "#86EFAC")
        static let c400 = Color(hex: "#4ADE80")
        static let c500 = Color(hex: "#22C55E")
        static let c600 = Color(hex: "#16A34A")
        static let c700 = Color(hex: "#15803D")
        static let c800 = Color(hex: "#166534")
        static let c900 = Color(hex: "#14532D")
        static let c950 = Color(hex: "#052E16")
    }

    enum Emerald {
        static let c50 = Color(hex: "#ECFDF5")
        static let c100 = Color(hex: "#D1FAE5")
        static let c200 = Color(hex: "#A7F3D0")
        static let c300 = Color(hex: "#6EE7B7")
        static let c400 = Color(hex: "#34D399")
        static let c500 = Color(hex: "#10B981")
        static let c600 = Color(hex: "#059669")
        static let c700 = Color(hex: "#047857")
        static let c800 = Color(hex: "#065F46")
        static let c900 = Color(hex: "#064E3B")
        static let c950 = Color(hex: "#022C22")
    }

    enum Teal {
        static let c50 = Color(hex: "#F0FDFA")
        static let c100 = Color(hex: "#CCFBF1")
        static let c200 = Color(hex: "#99F6E4")
        static let c300 = Color(hex: "#5EEAD4")
        static let c400 = Color(hex: "#2DD4BF")
        static let c500 = Color(hex: "#14B8A6")
        static let c600 = Color(hex: "#0D9488")
        static let c700 = Color(hex: "#0F766E")
        static let c800 = Color(hex: "#115E59")
        static let c900 = Color(hex: "#134E4A")
        static let c950 = Color(hex: "#042F2E")
    }

    enum Cyan {
        static let c50 = Color(hex: "#ECFEFF")
        static let c100 = Color(hex: "#CFFAFE")
        static let c200 = Color(hex: "#A5F3FC")
        static let c300 = Color(hex: "#67E8F9")
        static let c400 = Color(hex: "#22D3EE")
        static let c500 = Color(hex: "#06B6D4")
        static let c600 = Color(hex: "#0891B2")
        static let c700 = Color(hex: "#0E7490")
        static let c800 = Color(hex: "#155E75")
        static let c900 = Color(hex: "#164E63")
        static let c950 = Color(hex: "#083344")
    }

    enum Sky {
        static let c50 = Color(hex: "#F0F9FF")
        static let c100 = Color(hex: "#E0F2FE")
        static let c200 = Color(hex: "#BAE6FD")
        static let c300 = Color(hex: "#7DD3FC")
        static let c400 = Color(hex: "#38BDF8")
        static let c500 = Color(hex: "#0EA5E9")
        static let c600 = Color(hex: "#0284C7")
        static let c700 = Color(hex: "#0369A1")
        static let c800 = Color(hex: "#075985")
        static let c900 = Color(hex: "#0C4A6E")
        static let c950 = Color(hex: "#082F49")
    }

    enum Blue {
        static let c50 = Color(hex: "#EFF6FF")
        static let c100 = Color(hex: "#DBEAFE")
        static let c200 = Color(hex: "#BFDBFE")
        static let c300 = Color(hex: "#93C5FD")
        static let c400 = Color(hex: "#60A5FA")
        static let c500 = Color(hex: "#3B82F6")
        static let c600 = Color(hex: "#2563EB")
        static let c700 = Color(hex: "#1D4ED8")
        static let c800 = Color(hex: "#1E40AF")
        static let c900 = Color(hex: "#1E3A8A")
        static let c950 = Color(hex: "#172554")
    }

    enum Indigo {
        static let c50 = Color(hex: "#EEF2FF")
        static let c100 = Color(hex: "#E0E7FF")
        static let c200 = Color(hex: "#C7D2FE")
        static let c300 = Color(hex: "#A5B4FC")
        static let c400 = Color(hex: "#818CF8")
        static let c500 = Color(hex: "#6366F1")
        static let c600 = Color(hex: "#4F46E5")
        static let c700 = Color(hex: "#4338CA")
        static let c800 = Color(hex: "#3730A3")
        static let c900 = Color(hex: "#312E81")
        static let c950 = Color(hex: "#1E1B4B")
    }

    enum Violet {
        static let c50 = Color(hex: "#F5F3FF")
        static let c100 = Color(hex: "#EDE9FE")
        static let c200 = Color(hex: "#DDD6FE")
        static let c300 = Color(hex: "#C4B5FD")
        static let c400 = Color(hex: "#A78BFA")
        static let c500 = Color(hex: "#8B5CF6")
        static let c600 = Color(hex: "#7C3AED")
        static let c700 = Color(hex: "#6D28D9")
        static let c800 = Color(hex: "#5B21B6")
        static let c900 = Color(hex: "#4C1D95")
        static let c950 = Color(hex: "#1E1B4B")
    }

    enum Purple {
        static let c50 = Color(hex: "#FAF5FF")
        static let c100 = Color(hex: "#F3E8FF")
        static let c200 = Color(hex: "#E9D5FF")
        static let c300 = Color(hex: "#D8B4FE")
        static let c400 = Color(hex: "#C084FC")
        static let c500 = Color(hex: "#A855F7")
        static let c600 = Color(hex: "#9333EA")
        static let c700 = Color(hex: "#7E22CE")
        static let c800 = Color(hex: "#6B21A8")
        static let c900 = Color(hex: "#581C87")
        static let c950 = Color(hex: "#3B0764")
    }

    enum Fuchsia {
        static let c50 = Color(hex: "#FDF4FF")
        static let c100 = Color(hex: "#FAE8FF")
        static let c200 = Color(hex: "#F5D0FE")
        static let c300 = Color(hex: "#F0ABFC")
        static let c400 = Color(hex: "#E879F9")
        static let c500 = Color(hex: "#D946EF")
        static let c600 = Color(hex: "#C026D3")
        static let c700 = Color(hex: "#A21CAF")
        static let c800 = Color(hex: "#86198F")
        static let c900 = Color(hex: "#701A75")
        static let c950 = Color(hex: "#4A044E")
    }

    enum Pink {
        static let c50 = Color(hex: "#FDF2F8")
        static let c100 = Color(hex: "#FCE7F3")
        static let c200 = Color(hex: "#FBCFE8")
        static let c300 = Color(hex: "#F9A8D4")
        static let c400 = Color(hex: "#F472B6")
        static let c500 = Color(hex: "#EC4899")
        static let c600 = Color(hex: "#DB2777")
        static let c700 = Color(hex: "#BE185D")
        static let c800 = Color(hex: "#9D174D")
        static let c900 = Color(hex: "#831843")
        static let c950 = Color(hex: "#500724")
    }

    enum Rose {
        static let c50 = Color(hex: "#FFF1F2")
        static let c100 = Color(hex: "#FFE4E6")
        static let c200 = Color(hex: "#FECDD3")
        static let c300 = Color(hex: "#FDA4AF")
        static let c400 = Color(hex: "#FB7185")
        static let c500 = Color(hex: "#F43F5E")
        static let c600 = Color(hex: "#E11D48")
        static let c700 = Color(hex: "#BE123C")
        static let c800 = Color(hex: "#9F1239")
        static let c900 = Color(hex: "#881337")
        static let c950 = Color(hex: "#4C0519")
    }

    typealias Finance = Green
    typealias Gym = Violet
    typealias Food = Orange
    typealias Quotes = Indigo
    typealias Body = Cyan
    typealias Ideas = Yellow
    typealias LifeGoals = Pink
    typealias Habits = Lime
    typealias Recommendations = Teal
    typealias Notes = Amber
    typealias Reminders = Red

    struct PaletteSwatch: Identifiable {
        let scale: String
        let hex: String

        var id: String { scale }
        var color: Color { Color(hex: hex) }
    }

    struct PaletteFamily: Identifiable {
        let id: String
        let title: String
        let category: String?
        let swatches: [PaletteSwatch]
    }

    static let categorizedFamilies: [PaletteFamily] = [
        family(id: "green", title: "Green", category: "Finanzas", swatches: [
            ("50", "#F0FDF4"), ("100", "#DCFCE7"), ("200", "#BBF7D0"), ("300", "#86EFAC"), ("400", "#4ADE80"),
            ("500", "#22C55E"), ("600", "#16A34A"), ("700", "#15803D"), ("800", "#166534"), ("900", "#14532D"), ("950", "#052E16")
        ]),
        family(id: "violet", title: "Violet", category: "Gym", swatches: [
            ("50", "#F5F3FF"), ("100", "#EDE9FE"), ("200", "#DDD6FE"), ("300", "#C4B5FD"), ("400", "#A78BFA"),
            ("500", "#8B5CF6"), ("600", "#7C3AED"), ("700", "#6D28D9"), ("800", "#5B21B6"), ("900", "#4C1D95"), ("950", "#1E1B4B")
        ]),
        family(id: "orange", title: "Orange", category: "Comidas", swatches: [
            ("50", "#FFF7ED"), ("100", "#FFEDD5"), ("200", "#FED7AA"), ("300", "#FDBA74"), ("400", "#FB923C"),
            ("500", "#F97316"), ("600", "#EA580C"), ("700", "#C2410C"), ("800", "#9A3412"), ("900", "#7C2D12"), ("950", "#431407")
        ]),
        family(id: "indigo", title: "Indigo", category: "Frases", swatches: [
            ("50", "#EEF2FF"), ("100", "#E0E7FF"), ("200", "#C7D2FE"), ("300", "#A5B4FC"), ("400", "#818CF8"),
            ("500", "#6366F1"), ("600", "#4F46E5"), ("700", "#4338CA"), ("800", "#3730A3"), ("900", "#312E81"), ("950", "#1E1B4B")
        ]),
        family(id: "cyan", title: "Cyan", category: "Medidas corporales", swatches: [
            ("50", "#ECFEFF"), ("100", "#CFFAFE"), ("200", "#A5F3FC"), ("300", "#67E8F9"), ("400", "#22D3EE"),
            ("500", "#06B6D4"), ("600", "#0891B2"), ("700", "#0E7490"), ("800", "#155E75"), ("900", "#164E63"), ("950", "#083344")
        ]),
        family(id: "yellow", title: "Yellow", category: "Ideas", swatches: [
            ("50", "#FEFCE8"), ("100", "#FEF9C3"), ("200", "#FEF08A"), ("300", "#FDE047"), ("400", "#FACC15"),
            ("500", "#EAB308"), ("600", "#CA8A04"), ("700", "#A16207"), ("800", "#854D0E"), ("900", "#713F12"), ("950", "#422006")
        ]),
        family(id: "pink", title: "Pink", category: "Metas de vida", swatches: [
            ("50", "#FDF2F8"), ("100", "#FCE7F3"), ("200", "#FBCFE8"), ("300", "#F9A8D4"), ("400", "#F472B6"),
            ("500", "#EC4899"), ("600", "#DB2777"), ("700", "#BE185D"), ("800", "#9D174D"), ("900", "#831843"), ("950", "#500724")
        ]),
        family(id: "lime", title: "Lime", category: "Habitos", swatches: [
            ("50", "#F7FEE7"), ("100", "#ECFCCB"), ("200", "#D9F99D"), ("300", "#BEF264"), ("400", "#A3E635"),
            ("500", "#84CC16"), ("600", "#65A30D"), ("700", "#4D7C0F"), ("800", "#3F6212"), ("900", "#365314"), ("950", "#1A2E05")
        ]),
        family(id: "teal", title: "Teal", category: "Recomendaciones", swatches: [
            ("50", "#F0FDFA"), ("100", "#CCFBF1"), ("200", "#99F6E4"), ("300", "#5EEAD4"), ("400", "#2DD4BF"),
            ("500", "#14B8A6"), ("600", "#0D9488"), ("700", "#0F766E"), ("800", "#115E59"), ("900", "#134E4A"), ("950", "#042F2E")
        ]),
        family(id: "amber", title: "Amber", category: "Notas", swatches: [
            ("50", "#FFFBEB"), ("100", "#FEF3C7"), ("200", "#FDE68A"), ("300", "#FCD34D"), ("400", "#FBBF24"),
            ("500", "#F59E0B"), ("600", "#D97706"), ("700", "#B45309"), ("800", "#92400E"), ("900", "#78350F"), ("950", "#451A03")
        ]),
        family(id: "red", title: "Red", category: "Recordatorios", swatches: [
            ("50", "#FEF2F2"), ("100", "#FEE2E2"), ("200", "#FECACA"), ("300", "#FCA5A5"), ("400", "#F87171"),
            ("500", "#EF4444"), ("600", "#DC2626"), ("700", "#B91C1C"), ("800", "#991B1B"), ("900", "#7F1D1D"), ("950", "#450A0A")
        ])
    ]

    static let futureFamilies: [PaletteFamily] = [
        family(id: "emerald", title: "Emerald", category: nil, swatches: [
            ("50", "#ECFDF5"), ("100", "#D1FAE5"), ("200", "#A7F3D0"), ("300", "#6EE7B7"), ("400", "#34D399"),
            ("500", "#10B981"), ("600", "#059669"), ("700", "#047857"), ("800", "#065F46"), ("900", "#064E3B"), ("950", "#022C22")
        ]),
        family(id: "sky", title: "Sky", category: nil, swatches: [
            ("50", "#F0F9FF"), ("100", "#E0F2FE"), ("200", "#BAE6FD"), ("300", "#7DD3FC"), ("400", "#38BDF8"),
            ("500", "#0EA5E9"), ("600", "#0284C7"), ("700", "#0369A1"), ("800", "#075985"), ("900", "#0C4A6E"), ("950", "#082F49")
        ]),
        family(id: "blue", title: "Blue", category: nil, swatches: [
            ("50", "#EFF6FF"), ("100", "#DBEAFE"), ("200", "#BFDBFE"), ("300", "#93C5FD"), ("400", "#60A5FA"),
            ("500", "#3B82F6"), ("600", "#2563EB"), ("700", "#1D4ED8"), ("800", "#1E40AF"), ("900", "#1E3A8A"), ("950", "#172554")
        ]),
        family(id: "purple", title: "Purple", category: nil, swatches: [
            ("50", "#FAF5FF"), ("100", "#F3E8FF"), ("200", "#E9D5FF"), ("300", "#D8B4FE"), ("400", "#C084FC"),
            ("500", "#A855F7"), ("600", "#9333EA"), ("700", "#7E22CE"), ("800", "#6B21A8"), ("900", "#581C87"), ("950", "#3B0764")
        ]),
        family(id: "fuchsia", title: "Fuchsia", category: nil, swatches: [
            ("50", "#FDF4FF"), ("100", "#FAE8FF"), ("200", "#F5D0FE"), ("300", "#F0ABFC"), ("400", "#E879F9"),
            ("500", "#D946EF"), ("600", "#C026D3"), ("700", "#A21CAF"), ("800", "#86198F"), ("900", "#701A75"), ("950", "#4A044E")
        ]),
        family(id: "rose", title: "Rose", category: nil, swatches: [
            ("50", "#FFF1F2"), ("100", "#FFE4E6"), ("200", "#FECDD3"), ("300", "#FDA4AF"), ("400", "#FB7185"),
            ("500", "#F43F5E"), ("600", "#E11D48"), ("700", "#BE123C"), ("800", "#9F1239"), ("900", "#881337"), ("950", "#4C0519")
        ])
    ]

    private static func family(
        id: String,
        title: String,
        category: String?,
        swatches: [(String, String)]
    ) -> PaletteFamily {
        PaletteFamily(
            id: id,
            title: title,
            category: category,
            swatches: swatches.map { scale, hex in
                PaletteSwatch(scale: scale, hex: hex)
            }
        )
    }
}

extension Color {
    init(hex: String, opacity: Double = 1) {
        let cleanHex = hex
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static let appTextPrimary = Color(uiColor: .label)
    static let appTextSecondary = Color(uiColor: .secondaryLabel)
    static let appSurface = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .secondarySystemBackground
        }
        return UIColor(white: 1.0, alpha: 0.96)
    })
    static let appField = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .tertiarySystemBackground
        }
        return UIColor(white: 1.0, alpha: 0.99)
    })
    static let appBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .systemGroupedBackground
        }
        return UIColor(white: 1.0, alpha: 1.0)
    })
    static let appBackgroundSecondary = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .secondarySystemGroupedBackground
        }
        return UIColor(white: 0.99, alpha: 1.0)
    })
    static let appTabBarBackground = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return .systemBackground
        }
        return UIColor(white: 1.0, alpha: 1.0)
    })
    static let appStrokeSoft = Color(uiColor: .separator).opacity(0.32)
    static let appAxis = Color(uiColor: .separator).opacity(0.55)

    static let financeIncomeAccent = Color(red: 0.08, green: 0.68, blue: 0.47)
    static let financeExpenseAccent = Color(red: 0.90, green: 0.20, blue: 0.22)
    static let financeTransferAccent = Color(red: 0.13, green: 0.49, blue: 0.89)
}
