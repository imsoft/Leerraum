import SwiftUI
import SwiftData
import OSLog

private enum RootTab: Hashable {
    case finance
    case gym
    case food
    case quotes
    case more

    var analyticsName: String {
        switch self {
        case .finance:
            return "finance"
        case .gym:
            return "gym"
        case .food:
            return "food"
        case .quotes:
            return "quotes"
        case .more:
            return "more"
        }
    }
}

private enum MoreDestination: String, CaseIterable, Identifiable {
    case notes
    case bodyMeasurements
    case recommendations
    case appIdeas
    case lifeGoals
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes:
            return "Notas"
        case .bodyMeasurements:
            return "Medidas corporales"
        case .recommendations:
            return "Recomendaciones"
        case .appIdeas:
            return "Ideas de la app"
        case .lifeGoals:
            return "Metas de vida"
        case .settings:
            return "Ajustes"
        }
    }

    var subtitle: String {
        switch self {
        case .notes:
            return "Guarda notas por categoria y color."
        case .bodyMeasurements:
            return "Registra peso y progreso en el tiempo."
        case .recommendations:
            return "Guarda series, peliculas y musica."
        case .appIdeas:
            return "Anota mejoras y funciones futuras."
        case .lifeGoals:
            return "Define objetivos y prioridades."
        case .settings:
            return "Tema y configuracion de la app."
        }
    }

    var icon: String {
        switch self {
        case .notes:
            return "note.text"
        case .bodyMeasurements:
            return "ruler"
        case .recommendations:
            return "sparkles.rectangle.stack"
        case .appIdeas:
            return "lightbulb"
        case .lifeGoals:
            return "target"
        case .settings:
            return "paintbrush"
        }
    }

    var tint: Color {
        switch self {
        case .notes:
            return AppPalette.Notes.c700
        case .bodyMeasurements:
            return AppPalette.Body.c700
        case .recommendations:
            return AppPalette.Recommendations.c700
        case .appIdeas:
            return AppPalette.Ideas.c700
        case .lifeGoals:
            return AppPalette.LifeGoals.c700
        case .settings:
            return Color(red: 0.13, green: 0.49, blue: 0.89)
        }
    }

}

struct RootTabView: View {
    @State private var selectedTab: RootTab = .finance
    @State private var deepLinkedQuoteID: UUID?
    @State private var quoteSchedulingTask: Task<Void, Never>?
    @State private var lastQuoteSchedulingSignature: Int?
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \QuoteMessage.createdAt, order: .reverse) private var quotes: [QuoteMessage]
    @AppStorage(AppStorageKey.themeMode) private var themeModeRawValue = AppThemeMode.system.rawValue

    private var selectedThemeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRawValue) ?? .system
    }

    private var selectedThemeModeBinding: Binding<AppThemeMode> {
        Binding(
            get: { selectedThemeMode },
            set: { themeModeRawValue = $0.rawValue }
        )
    }

    private var tabTint: Color {
        switch selectedTab {
        case .finance:
            return AppPalette.Finance.c600
        case .gym:
            return AppPalette.Gym.c600
        case .food:
            return AppPalette.Food.c600
        case .quotes:
            return AppPalette.Quotes.c600
        case .more:
            return Color(red: 0.13, green: 0.49, blue: 0.89)
        }
    }

    private var quoteNotificationSignature: Int {
        var hasher = Hasher()
        for quote in quotes {
            hasher.combine(quote.id)
            hasher.combine(quote.isActive)
            hasher.combine(quote.text)
            hasher.combine(quote.author)
        }
        return hasher.finalize()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("Finanzas", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(RootTab.finance)

            GymView()
                .tabItem {
                    Label("Gym", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(RootTab.gym)

            FoodLogView()
                .tabItem {
                    Label("Comidas", systemImage: "fork.knife.circle")
                }
                .tag(RootTab.food)

            QuotesView(deepLinkedQuoteID: $deepLinkedQuoteID)
                .tabItem {
                    Label("Frases", systemImage: "quote.bubble")
                }
                .tag(RootTab.quotes)

            MoreHubView(themeMode: selectedThemeModeBinding)
                .tabItem {
                    Label("Más", systemImage: "square.grid.2x2")
                }
                .tag(RootTab.more)
        }
        .tint(tabTint)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.appTabBarBackground, for: .tabBar)
        .preferredColorScheme(selectedThemeMode.preferredColorScheme)
        .onAppear {
            let interval = Observability.appSignposter.beginInterval("rootTab.onAppear")
            defer { Observability.appSignposter.endInterval("rootTab.onAppear", interval) }
            AppNotificationService.shared.requestAuthorizationIfNeeded()
            AppNotificationService.shared.scheduleMonthlyFinanceReviewReminders()
            scheduleQuoteRemindersIfNeeded(force: true)
            openPendingQuoteIfNeeded()
            Observability.debug(Observability.appLogger, "RootTabView did appear.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let interval = Observability.appSignposter.beginInterval("rootTab.sceneActive")
            defer { Observability.appSignposter.endInterval("rootTab.sceneActive", interval) }
            AppNotificationService.shared.scheduleMonthlyFinanceReviewReminders()
            scheduleQuoteRemindersIfNeeded()
            openPendingQuoteIfNeeded()
            Observability.debug(Observability.appLogger, "Scene became active; reminders refreshed.")
        }
        .onChange(of: quoteNotificationSignature) { _, _ in
            scheduleQuoteRemindersIfNeeded()
        }
        .onChange(of: selectedTab) { _, newTab in
            Observability.debug(
                Observability.navigationLogger,
                "Tab selected: \(newTab.analyticsName)"
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openQuoteMessage)) { notification in
            guard let quoteID = notification.object as? UUID else { return }
            openQuote(with: quoteID)
        }
        .onDisappear {
            quoteSchedulingTask?.cancel()
            quoteSchedulingTask = nil
        }
    }

    private func openQuote(with id: UUID) {
        let interval = Observability.navigationSignposter.beginInterval("rootTab.openQuote")
        defer { Observability.navigationSignposter.endInterval("rootTab.openQuote", interval) }
        deepLinkedQuoteID = id
        selectedTab = .quotes
        Observability.debug(
            Observability.navigationLogger,
            "Deep link to quote applied: \(id.uuidString)"
        )
    }

    private func openPendingQuoteIfNeeded() {
        guard let pendingID = AppNotificationService.shared.consumePendingQuoteMessageID() else { return }
        Observability.debug(
            Observability.navigationLogger,
            "Consumed pending quote id: \(pendingID.uuidString)"
        )
        openQuote(with: pendingID)
    }

    private func scheduleQuoteRemindersIfNeeded(force: Bool = false) {
        if !force, lastQuoteSchedulingSignature == quoteNotificationSignature {
            Observability.debug(
                Observability.notificationsLogger,
                "Skipped quote scheduling in RootTabView: unchanged signature."
            )
            return
        }
        lastQuoteSchedulingSignature = quoteNotificationSignature

        quoteSchedulingTask?.cancel()
        quoteSchedulingTask = Task {
            let interval = Observability.notificationSignposter.beginInterval("rootTab.quoteSchedulingTask")
            defer { Observability.notificationSignposter.endInterval("rootTab.quoteSchedulingTask", interval) }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            Observability.debug(
                Observability.notificationsLogger,
                "Running quote scheduling task with \(quotes.count) quotes."
            )
            AppNotificationService.shared.scheduleRandomQuoteReminders(quotes: quotes)
        }
    }
}

private struct MoreHubView: View {
    @Binding var themeMode: AppThemeMode
    @State private var selectedDestination: MoreDestination?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackground,
                        Color.appBackgroundSecondary,
                        Color.appBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(MoreDestination.allCases) { destination in
                                MoreDestinationCard(destination: destination) {
                                    selectedDestination = destination
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Leerraum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedDestination) { destination in
                destinationView(for: destination)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MoreDestination) -> some View {
        switch destination {
        case .notes:
            NotesView()
        case .bodyMeasurements:
            BodyMeasurementsView()
        case .recommendations:
            RecommendationsView()
        case .appIdeas:
            AppIdeasView()
        case .lifeGoals:
            LifeGoalsView()
        case .settings:
            AppearanceSettingsView(themeMode: $themeMode)
        }
    }
}

private struct MoreDestinationCard: View {
    let destination: MoreDestination
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: destination.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(destination.tint)
                        .frame(width: 32, height: 32)
                        .background(destination.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 18, height: 18, alignment: .center)
                }

                Text(destination.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                Text(destination.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appStrokeSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppearanceSettingsView: View {
    @Binding var themeMode: AppThemeMode
    @AppStorage(AppStorageKey.exchangeRateProvider) private var exchangeProviderRawValue = ExchangeRateProviderPreference.automatic.rawValue
    @AppStorage(AppStorageKey.banxicoToken) private var banxicoToken = ""

    private var selectedProvider: ExchangeRateProviderPreference {
        ExchangeRateProviderPreference(rawValue: exchangeProviderRawValue) ?? .automatic
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section("Tema") {
                        ThemeModePicker(mode: $themeMode)

                        Text("Sistema usa la configuracion de tu iPhone.")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Section("Tipo de cambio USD/MXN") {
                        Picker("Proveedor", selection: $exchangeProviderRawValue) {
                            ForEach(ExchangeRateProviderPreference.allCases) { provider in
                                Text(provider.title).tag(provider.rawValue)
                            }
                        }

                        Text(selectedProvider.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)

                        if selectedProvider == .banxico || selectedProvider == .automatic {
                            SecureField("Token Banxico (SIE)", text: $banxicoToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Text("Si pones token, Automatico prioriza Banxico.")
                                .font(.caption2)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
                .contentMargins(.top, 4, for: .scrollContent)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .animation(.easeInOut(duration: 0.2), value: themeMode)
    }
}
