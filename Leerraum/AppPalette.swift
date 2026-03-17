import SwiftUI

enum AppPalette {
    enum Finance {
        static let c50 = Color(hex: "#F0FDF4")
        static let c100 = Color(hex: "#DCFCE7")
        static let c200 = Color(hex: "#B9F8CF")
        static let c300 = Color(hex: "#7BF1A8")
        static let c400 = Color(hex: "#05DF72")
        static let c500 = Color(hex: "#31C950")
        static let c600 = Color(hex: "#2AA63E")
        static let c700 = Color(hex: "#178236")
        static let c800 = Color(hex: "#016630")
        static let c900 = Color(hex: "#0D542B")
        static let c950 = Color(hex: "#032E15")
    }

    enum Gym {
        static let c50 = Color(hex: "#F5F3FF")
        static let c100 = Color(hex: "#EDE9FE")
        static let c200 = Color(hex: "#DDD6FF")
        static let c300 = Color(hex: "#C4B4FF")
        static let c400 = Color(hex: "#A684FF")
        static let c500 = Color(hex: "#8E51FF")
        static let c600 = Color(hex: "#7F22FE")
        static let c700 = Color(hex: "#7008E7")
        static let c800 = Color(hex: "#5D0EC0")
        static let c900 = Color(hex: "#4D179A")
        static let c950 = Color(hex: "#2F0D68")
    }

    enum Food {
        static let c50 = Color(hex: "#FFF7ED")
        static let c100 = Color(hex: "#FFEDD4")
        static let c200 = Color(hex: "#FFD6A7")
        static let c300 = Color(hex: "#FFB86A")
        static let c400 = Color(hex: "#FF8904")
        static let c500 = Color(hex: "#FF692A")
        static let c600 = Color(hex: "#F54927")
        static let c700 = Color(hex: "#CA3519")
        static let c800 = Color(hex: "#9F2D01")
        static let c900 = Color(hex: "#7E2A0C")
        static let c950 = Color(hex: "#441306")
    }

    enum Quotes {
        static let c50 = Color(hex: "#EEF2FF")
        static let c100 = Color(hex: "#E0E7FF")
        static let c200 = Color(hex: "#C6D2FF")
        static let c300 = Color(hex: "#A3B3FF")
        static let c400 = Color(hex: "#7C86FF")
        static let c500 = Color(hex: "#615FFF")
        static let c600 = Color(hex: "#4F39F6")
        static let c700 = Color(hex: "#432DD7")
        static let c800 = Color(hex: "#372AAC")
        static let c900 = Color(hex: "#312C85")
        static let c950 = Color(hex: "#1E1A4D")
    }

    enum Body {
        static let c50 = Color(hex: "#F0F9FF")
        static let c100 = Color(hex: "#DFF2FE")
        static let c200 = Color(hex: "#B8E6FE")
        static let c300 = Color(hex: "#74D4FF")
        static let c400 = Color(hex: "#21BCFF")
        static let c500 = Color(hex: "#34A6F4")
        static let c600 = Color(hex: "#2984D1")
        static let c700 = Color(hex: "#1C69A8")
        static let c800 = Color(hex: "#10598A")
        static let c900 = Color(hex: "#024A70")
        static let c950 = Color(hex: "#052F4A")
    }

    enum Ideas {
        static let c50 = Color(hex: "#FFFBEB")
        static let c100 = Color(hex: "#FEF3C6")
        static let c200 = Color(hex: "#FEE685")
        static let c300 = Color(hex: "#FFD230")
        static let c400 = Color(hex: "#FFB93B")
        static let c500 = Color(hex: "#FE9A37")
        static let c600 = Color(hex: "#E1712B")
        static let c700 = Color(hex: "#BB4D1A")
        static let c800 = Color(hex: "#973C08")
        static let c900 = Color(hex: "#7B3306")
        static let c950 = Color(hex: "#461901")
    }

    enum LifeGoals {
        static let c50 = Color(hex: "#FDF2F8")
        static let c100 = Color(hex: "#FCE7F3")
        static let c200 = Color(hex: "#FCCEE8")
        static let c300 = Color(hex: "#FDA5D5")
        static let c400 = Color(hex: "#FB64B6")
        static let c500 = Color(hex: "#F6339A")
        static let c600 = Color(hex: "#E61876")
        static let c700 = Color(hex: "#C6185C")
        static let c800 = Color(hex: "#A3044C")
        static let c900 = Color(hex: "#861043")
        static let c950 = Color(hex: "#510424")
    }

    enum Habits {
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

    enum Recommendations {
        static let c50 = Color(hex: "#F7FEE7")
        static let c100 = Color(hex: "#ECFCCA")
        static let c200 = Color(hex: "#D8F999")
        static let c300 = Color(hex: "#BBF451")
        static let c400 = Color(hex: "#9AE630")
        static let c500 = Color(hex: "#7CCF35")
        static let c600 = Color(hex: "#5EA529")
        static let c700 = Color(hex: "#497D15")
        static let c800 = Color(hex: "#3C6301")
        static let c900 = Color(hex: "#35530E")
        static let c950 = Color(hex: "#192E03")
    }

    enum Notes {
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
