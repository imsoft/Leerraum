import SwiftUI

struct FeatureGradientPalette {
    let light: [Color]
    let dark: [Color]

    static let gym = FeatureGradientPalette(
        light: [AppPalette.Gym.c50, AppPalette.Gym.c100, AppPalette.Gym.c200],
        dark: [AppPalette.Gym.c950, AppPalette.Gym.c900, AppPalette.Gym.c800]
    )

    static let food = FeatureGradientPalette(
        light: [AppPalette.Food.c50, AppPalette.Food.c100, AppPalette.Food.c200],
        dark: [AppPalette.Food.c950, AppPalette.Food.c900, AppPalette.Food.c800]
    )

    static let quotes = FeatureGradientPalette(
        light: [AppPalette.Quotes.c50, AppPalette.Quotes.c100, AppPalette.Quotes.c200],
        dark: [AppPalette.Quotes.c950, AppPalette.Quotes.c900, AppPalette.Quotes.c800]
    )

    static let body = FeatureGradientPalette(
        light: [AppPalette.Body.c50, AppPalette.Body.c100, AppPalette.Body.c200],
        dark: [AppPalette.Body.c950, AppPalette.Body.c900, AppPalette.Body.c800]
    )

    static let ideas = FeatureGradientPalette(
        light: [AppPalette.Ideas.c50, AppPalette.Ideas.c100, AppPalette.Ideas.c200],
        dark: [AppPalette.Ideas.c950, AppPalette.Ideas.c900, AppPalette.Ideas.c800]
    )

    static let lifeGoals = FeatureGradientPalette(
        light: [AppPalette.LifeGoals.c50, AppPalette.LifeGoals.c100, AppPalette.LifeGoals.c200],
        dark: [AppPalette.LifeGoals.c950, AppPalette.LifeGoals.c900, AppPalette.LifeGoals.c800]
    )

    static let habits = FeatureGradientPalette(
        light: [AppPalette.Habits.c50, AppPalette.Habits.c100, AppPalette.Habits.c200],
        dark: [AppPalette.Habits.c950, AppPalette.Habits.c900, AppPalette.Habits.c800]
    )

    static let recommendations = FeatureGradientPalette(
        light: [AppPalette.Recommendations.c50, AppPalette.Recommendations.c100, AppPalette.Recommendations.c200],
        dark: [AppPalette.Recommendations.c950, AppPalette.Recommendations.c900, AppPalette.Recommendations.c800]
    )

    static let notes = FeatureGradientPalette(
        light: [AppPalette.Notes.c50, AppPalette.Notes.c100, AppPalette.Notes.c200],
        dark: [AppPalette.Notes.c950, AppPalette.Notes.c900, AppPalette.Notes.c800]
    )
}

struct FeatureGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let palette: FeatureGradientPalette

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark ? palette.dark : palette.light,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FeatureSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            trailing
        }
    }
}
