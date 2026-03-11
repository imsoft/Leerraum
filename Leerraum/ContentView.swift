import SwiftUI
import SwiftData
import OSLog

enum TransactionFilter: String, CaseIterable, Identifiable {
    case all = "Todo"
    case income = "Ingresos"
    case expense = "Gastos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:
            return "square.grid.2x2.fill"
        case .income:
            return "arrow.down.left.circle.fill"
        case .expense:
            return "arrow.up.right.circle.fill"
        }
    }
}

enum ReportRange: String, CaseIterable, Identifiable {
    case week = "Semana"
    case month = "Mes"
    case year = "Año"

    var id: String { rawValue }
}

private enum ReadablePalette {
    static let secondaryText = Color.appTextSecondary
    static let cardBackground = Color.appSurface
    static let fieldBackground = Color.appField
    static let onDarkSecondaryText = Color.white.opacity(0.93)
    static let filterInactiveText = Color.appTextSecondary
    static let financeAccent = AppPalette.Finance.c600
    static let incomeAccent = Color.financeIncomeAccent
    static let expenseAccent = Color.financeExpenseAccent
    static let transferAccent = Color.financeTransferAccent
}

struct CategoryExpenseSummary: Identifiable {
    let category: String
    let amount: Double
    let ratio: Double

    var id: String { category }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \FixedTransaction.createdAt, order: .reverse) private var fixedTransactions: [FixedTransaction]
    @Query(sort: \Account.createdAt, order: .forward) private var accounts: [Account]
    @Query(sort: \CategoryBudget.createdAt, order: .reverse) private var budgets: [CategoryBudget]
    @Query(sort: \SavingsGoal.createdAt, order: .reverse) private var savingsGoals: [SavingsGoal]

    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedReportRange: ReportRange = .month
    @State private var showingAddSheet = false
    @State private var showingBudgetSheet = false
    @State private var showingSavingsGoalSheet = false
    @State private var showingContributionSheet = false
    @State private var transactionPendingDeletion: Transaction?
    @State private var budgetPendingDeletion: CategoryBudget?
    @State private var savingsGoalPendingDeletion: SavingsGoal?
    @State private var goalPendingContribution: SavingsGoal?
    @State private var showingFixedTransactionSheet = false
    @State private var fixedTransactionEditing: FixedTransaction?
    @StateObject private var dashboardViewModel = FinanceDashboardViewModel()
    @StateObject private var exchangeRateViewModel = USDMXNExchangeRateViewModel()
    @AppStorage(AppStorageKey.exchangeRateProvider) private var exchangeProviderRawValue = ExchangeRateProviderPreference.automatic.rawValue
    @AppStorage(AppStorageKey.banxicoToken) private var banxicoToken = ""
    @State private var dashboardRefreshTask: Task<Void, Never>?
    private var usdToMxnRate: Double { exchangeRateViewModel.effectiveRate }
    private let financeBaseCurrencyCode = "MXN"

    private var selectedExchangeProvider: ExchangeRateProviderPreference {
        ExchangeRateProviderPreference(rawValue: exchangeProviderRawValue) ?? .automatic
    }

    private var hasBanxicoToken: Bool {
        !banxicoToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var dashboardSnapshot: FinanceDashboardSnapshot {
        dashboardViewModel.snapshot
    }

    private var filteredTransactions: [Transaction] {
        dashboardSnapshot.filteredTransactions
    }

    private var totalIncome: Double {
        dashboardSnapshot.totalIncome
    }

    private var totalExpense: Double {
        dashboardSnapshot.totalExpense
    }

    private var totalFixedIncome: Double {
        dashboardSnapshot.totalFixedIncome
    }

    private var totalFixedExpense: Double {
        dashboardSnapshot.totalFixedExpense
    }

    private var balance: Double {
        dashboardSnapshot.balance
    }

    private var currentMonthBudgets: [CategoryBudget] {
        dashboardSnapshot.currentMonthBudgets
    }

    private var reportPeriodTitle: String {
        dashboardSnapshot.reportPeriodTitle
    }

    private var reportIncome: Double {
        dashboardSnapshot.reportIncome
    }

    private var reportExpense: Double {
        dashboardSnapshot.reportExpense
    }

    private var reportBalance: Double {
        dashboardSnapshot.reportBalance
    }

    private var reportTransactionCount: Int {
        dashboardSnapshot.reportTransactionCount
    }

    private var reportTopExpenseCategories: [CategoryExpenseSummary] {
        dashboardSnapshot.reportTopExpenseCategories
    }

    private var currentMonthIncomeForComparison: Double {
        dashboardSnapshot.currentMonthIncomeForComparison
    }

    private var previousMonthIncomeForComparison: Double {
        dashboardSnapshot.previousMonthIncomeForComparison
    }

    private var currentMonthExpenseForComparison: Double {
        dashboardSnapshot.currentMonthExpenseForComparison
    }

    private var previousMonthExpenseForComparison: Double {
        dashboardSnapshot.previousMonthExpenseForComparison
    }

    private var currentMonthBalanceForComparison: Double {
        dashboardSnapshot.currentMonthBalanceForComparison
    }

    private var previousMonthBalanceForComparison: Double {
        dashboardSnapshot.previousMonthBalanceForComparison
    }

    private var currentMonthComparisonTitle: String {
        dashboardSnapshot.currentMonthComparisonTitle
    }

    private var previousMonthComparisonTitle: String {
        dashboardSnapshot.previousMonthComparisonTitle
    }

    private var incomeComparisonDeltaPercent: Double? {
        dashboardSnapshot.incomeComparisonDeltaPercent
    }

    private var expenseComparisonDeltaPercent: Double? {
        dashboardSnapshot.expenseComparisonDeltaPercent
    }

    private var balanceComparisonDeltaPercent: Double? {
        dashboardSnapshot.balanceComparisonDeltaPercent
    }

    private var movementComparisonDeltaPercent: Double? {
        dashboardSnapshot.movementComparisonDeltaPercent
    }

    private var currentMonthMovementCount: Int {
        dashboardSnapshot.currentMonthMovementCount
    }

    private var previousMonthMovementCount: Int {
        dashboardSnapshot.previousMonthMovementCount
    }

    private var dashboardRefreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(transactions.count)
        hasher.combine(fixedTransactions.count)
        hasher.combine(accounts.count)
        hasher.combine(budgets.count)
        hasher.combine(selectedFilter)
        hasher.combine(selectedReportRange)
        hasher.combine(Int((usdToMxnRate * 10_000).rounded()))
        return hasher.finalize()
    }

    private var exchangeRateRefreshSignature: Int {
        var hasher = Hasher()
        hasher.combine(Int((usdToMxnRate * 1_000_000).rounded()))
        hasher.combine(exchangeRateViewModel.sourceName)
        hasher.combine(exchangeRateViewModel.lastUpdated?.timeIntervalSince1970 ?? 0)
        return hasher.finalize()
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { transactionPendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    transactionPendingDeletion = nil
                }
            }
        )
    }

    private var budgetDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { budgetPendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    budgetPendingDeletion = nil
                }
            }
        )
    }

    private var savingsGoalDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { savingsGoalPendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    savingsGoalPendingDeletion = nil
                }
            }
        )
    }

    private var fixedTransactionsSection: some View {
        FixedTransactionsOverview(
            entries: fixedTransactions,
            fixedIncome: totalFixedIncome,
            fixedExpense: totalFixedExpense,
            onAddTap: startAddingFixedTransaction,
            onEditTap: openFixedTransactionEditor,
            onDeleteTap: deleteFixedTransaction
        )
    }

    private var exchangeRateSection: some View {
        ExchangeRateStatusCard(
            rate: usdToMxnRate,
            lastUpdated: exchangeRateViewModel.lastUpdated,
            sourceName: exchangeRateViewModel.sourceName,
            isLoading: exchangeRateViewModel.isLoading,
            errorMessage: exchangeRateViewModel.errorMessage,
            providerPreference: selectedExchangeProvider,
            hasBanxicoToken: hasBanxicoToken,
            onRefreshTap: {
                exchangeRateViewModel.refresh(force: true)
            }
        )
    }

    private var financeScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BalanceCard(
                    balance: balance,
                    income: totalIncome,
                    expense: totalExpense,
                    baseCurrencyCode: financeBaseCurrencyCode,
                    usdToMxnRate: usdToMxnRate
                )

                exchangeRateSection

                if !accounts.isEmpty {
                    AccountsOverview(
                        accounts: accounts,
                        balanceForAccount: balanceForAccount,
                        baseCurrencyCode: financeBaseCurrencyCode
                    )
                }

                fixedTransactionsSection

                BudgetsOverview(
                    budgets: currentMonthBudgets,
                    spentForBudget: spentForBudget,
                    onAddTap: { showingBudgetSheet = true },
                    onDeleteTap: { budgetPendingDeletion = $0 }
                )

                SavingsGoalsOverview(
                    goals: savingsGoals,
                    onAddTap: { showingSavingsGoalSheet = true },
                    onAddContributionTap: { goal in
                        goalPendingContribution = goal
                        showingContributionSheet = true
                    },
                    onDeleteTap: { savingsGoalPendingDeletion = $0 }
                )

                ReportsOverview(
                    selectedRange: $selectedReportRange,
                    periodTitle: reportPeriodTitle,
                    income: reportIncome,
                    expense: reportExpense,
                    balance: reportBalance,
                    transactionCount: reportTransactionCount,
                    topExpenseCategories: reportTopExpenseCategories,
                    baseCurrencyCode: financeBaseCurrencyCode
                )

                MonthComparisonOverview(
                    currentMonthTitle: currentMonthComparisonTitle,
                    previousMonthTitle: previousMonthComparisonTitle,
                    currentIncome: currentMonthIncomeForComparison,
                    previousIncome: previousMonthIncomeForComparison,
                    incomeDeltaPercent: incomeComparisonDeltaPercent,
                    currentExpense: currentMonthExpenseForComparison,
                    previousExpense: previousMonthExpenseForComparison,
                    expenseDeltaPercent: expenseComparisonDeltaPercent,
                    currentBalance: currentMonthBalanceForComparison,
                    previousBalance: previousMonthBalanceForComparison,
                    balanceDeltaPercent: balanceComparisonDeltaPercent,
                    currentMovements: currentMonthMovementCount,
                    previousMovements: previousMonthMovementCount,
                    movementDeltaPercent: movementComparisonDeltaPercent,
                    baseCurrencyCode: financeBaseCurrencyCode
                )

                FilterBar(selectedFilter: $selectedFilter)

                if filteredTransactions.isEmpty {
                    EmptyStateCard {
                        showingAddSheet = true
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTransactions, id: \.id) { transaction in
                            TransactionCard(transaction: transaction) {
                                transactionPendingDeletion = transaction
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
    }

    private var financeBaseView: some View {
        NavigationStack {
            ZStack {
                MainBackgroundView()
                    .ignoresSafeArea()

                financeScrollContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Finanzas")
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)
                }
            }
        }
    }

    var body: some View {
        applyLifecycle(
            to: applyAnimations(
                to: applyAlerts(
                    to: applySheets(
                        to: financeBaseView
                    )
                )
            )
        )
    }

    private func applySheets<Content: View>(to view: Content) -> some View {
        view
            .sheet(isPresented: $showingAddSheet) {
                AddTransactionView {
                    showingAddSheet = false
                }
            }
            .sheet(isPresented: $showingBudgetSheet) {
                AddBudgetView(
                    existingBudgets: budgets,
                    expenseCategories: expenseCategoriesForBudget
                )
            }
            .sheet(isPresented: $showingFixedTransactionSheet, onDismiss: {
                fixedTransactionEditing = nil
            }) {
                AddFixedTransactionView(initialEntry: fixedTransactionEditing) { payload in
                    if let fixedTransactionEditing {
                        updateFixedTransaction(fixedTransactionEditing, payload: payload)
                    } else {
                        createFixedTransaction(payload)
                    }
                } onDelete: {
                    if let fixedTransactionEditing {
                        deleteFixedTransaction(fixedTransactionEditing)
                    }
                }
            }
            .sheet(isPresented: $showingSavingsGoalSheet) {
                AddSavingsGoalView(existingGoals: savingsGoals)
            }
            .sheet(isPresented: $showingContributionSheet, onDismiss: {
                goalPendingContribution = nil
            }) {
                if let goalPendingContribution {
                    AddGoalContributionView(goal: goalPendingContribution)
                } else {
                    NavigationStack {
                        ContentUnavailableView(
                            "Meta no disponible",
                            systemImage: "flag.fill",
                            description: Text("Esta meta ya no existe.")
                        )
                    }
                }
            }
    }

    private func applyAlerts<Content: View>(to view: Content) -> some View {
        view
            .alert("Eliminar movimiento", isPresented: deleteAlertBinding, presenting: transactionPendingDeletion) { transaction in
                Button("Eliminar", role: .destructive) {
                    delete(transaction)
                }
                Button("Cancelar", role: .cancel) { }
            } message: { _ in
                Text("Esta acción no se puede deshacer.")
            }
            .alert("Eliminar presupuesto", isPresented: budgetDeleteAlertBinding, presenting: budgetPendingDeletion) { budget in
                Button("Eliminar", role: .destructive) {
                    deleteBudget(budget)
                }
                Button("Cancelar", role: .cancel) { }
            } message: { budget in
                Text("Se eliminara el presupuesto de \(budget.category) para este mes.")
            }
            .alert("Eliminar meta", isPresented: savingsGoalDeleteAlertBinding, presenting: savingsGoalPendingDeletion) { goal in
                Button("Eliminar", role: .destructive) {
                    deleteSavingsGoal(goal)
                }
                Button("Cancelar", role: .cancel) { }
            } message: { goal in
                Text("Se eliminara la meta \(goal.title).")
            }
    }

    private func applyAnimations<Content: View>(to view: Content) -> some View {
        view
            .animation(.snappy(duration: 0.35), value: selectedFilter)
            .animation(.snappy(duration: 0.35), value: selectedReportRange)
            .animation(.snappy(duration: 0.35), value: transactions.count)
            .animation(.snappy(duration: 0.35), value: currentMonthBudgets.count)
            .animation(.snappy(duration: 0.35), value: savingsGoals.count)
    }

    private func applyLifecycle<Content: View>(to view: Content) -> some View {
        view
            .onAppear {
                DefaultAccountSeeder.ensureDefaultAccountsIfNeeded(in: modelContext)
                exchangeRateViewModel.refreshIfNeeded()
                scheduleDashboardRefresh(immediate: true)
            }
            .onChange(of: dashboardRefreshSignature) { _, _ in
                scheduleDashboardRefresh()
            }
            .onChange(of: exchangeRateRefreshSignature) { _, _ in
                scheduleDashboardRefresh(immediate: true)
            }
            .onChange(of: exchangeProviderRawValue) { _, _ in
                exchangeRateViewModel.refresh(force: true)
            }
            .onChange(of: banxicoToken) { _, _ in
                exchangeRateViewModel.refresh(force: true)
            }
            .onDisappear {
                dashboardRefreshTask?.cancel()
                dashboardRefreshTask = nil
                exchangeRateViewModel.cancelRefresh()
            }
    }

    private func scheduleDashboardRefresh(immediate: Bool = false) {
        dashboardRefreshTask?.cancel()
        dashboardRefreshTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(120))
            }
            guard !Task.isCancelled else { return }
            refreshDashboardAnalytics()
        }
    }

    private func refreshDashboardAnalytics() {
        let interval = Observability.financeSignposter.beginInterval("finance.recompute")
        defer { Observability.financeSignposter.endInterval("finance.recompute", interval) }
        dashboardViewModel.recompute(
            transactions: transactions,
            fixedTransactions: fixedTransactions,
            accounts: accounts,
            budgets: budgets,
            selectedFilter: selectedFilter,
            selectedReportRange: selectedReportRange,
            usdToMxnRate: usdToMxnRate
        )
    }

    private func delete(_ transaction: Transaction) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(transaction)
        }
        transactionPendingDeletion = nil
        refreshDashboardAnalytics()
    }

    private func startAddingFixedTransaction() {
        fixedTransactionEditing = nil
        showingFixedTransactionSheet = true
    }

    private func openFixedTransactionEditor(_ entry: FixedTransaction) {
        fixedTransactionEditing = entry
        showingFixedTransactionSheet = true
    }

    private func createFixedTransaction(_ payload: FixedTransactionPayload) {
        let cleanedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCategory = payload.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, payload.amount > 0 else { return }

        let entry = FixedTransaction(
            title: cleanedTitle,
            category: cleanedCategory.isEmpty ? "Otros" : cleanedCategory,
            amount: payload.amount,
            dayOfMonth: payload.dayOfMonth,
            type: payload.type,
            isActive: payload.isActive
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.insert(entry)
        }
        refreshDashboardAnalytics()
    }

    private func updateFixedTransaction(_ entry: FixedTransaction, payload: FixedTransactionPayload) {
        let cleanedTitle = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCategory = payload.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, payload.amount > 0 else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            entry.title = cleanedTitle
            entry.category = cleanedCategory.isEmpty ? "Otros" : cleanedCategory
            entry.amount = payload.amount
            entry.dayOfMonth = max(1, min(payload.dayOfMonth, 31))
            entry.type = payload.type
            entry.isActive = payload.isActive
        }
        refreshDashboardAnalytics()
    }

    private func deleteFixedTransaction(_ entry: FixedTransaction) {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(entry)
        }
        if fixedTransactionEditing?.id == entry.id {
            fixedTransactionEditing = nil
        }
        refreshDashboardAnalytics()
    }

    private func balanceForAccount(_ account: Account) -> Double {
        dashboardSnapshot.accountBalanceByID[account.id] ?? account.initialBalance
    }

    private var expenseCategoriesForBudget: [String] {
        dashboardSnapshot.expenseCategoriesForBudget
    }

    private func spentForBudget(_ budget: CategoryBudget) -> Double {
        dashboardSnapshot.spentByBudgetID[budget.id] ?? 0
    }

    private func deleteBudget(_ budget: CategoryBudget) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(budget)
        }
        budgetPendingDeletion = nil
    }

    private func deleteSavingsGoal(_ goal: SavingsGoal) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(goal)
        }
        savingsGoalPendingDeletion = nil
    }

}

private struct MainBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [AppPalette.Finance.c950, AppPalette.Finance.c900]
                : [AppPalette.Finance.c50, AppPalette.Finance.c100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    (colorScheme == .dark ? AppPalette.Finance.c700 : AppPalette.Finance.c300)
                        .opacity(colorScheme == .dark ? 0.20 : 0.22)
                )
                .frame(width: 240, height: 240)
                .blur(radius: 14)
                .offset(x: -130, y: -280)

            Circle()
                .fill(
                    (colorScheme == .dark ? AppPalette.Finance.c600 : AppPalette.Finance.c400)
                        .opacity(colorScheme == .dark ? 0.14 : 0.16)
                )
                .frame(width: 260, height: 260)
                .blur(radius: 16)
                .offset(x: 150, y: 280)
        }
    }
}

private struct BalanceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let balance: Double
    let income: Double
    let expense: Double
    let baseCurrencyCode: String
    let usdToMxnRate: Double

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [AppPalette.Finance.c900, AppPalette.Finance.c700]
        }
        return [AppPalette.Finance.c600, AppPalette.Finance.c400]
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.24 : 0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance total (\(baseCurrencyCode))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ReadablePalette.onDarkSecondaryText)
                .fontDesign(.rounded)

            Text(balance.currencyText(code: baseCurrencyCode))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Incluye conversion USD -> MXN (1 USD = \(usdToMxnRate.formatted(.number.precision(.fractionLength(4)))) MXN)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(ReadablePalette.onDarkSecondaryText)

            HStack(spacing: 10) {
                MetricPill(
                    "Ingresos",
                    value: income.currencyText(code: baseCurrencyCode),
                    icon: "arrow.down.left",
                    tint: ReadablePalette.incomeAccent
                )

                MetricPill(
                    "Gastos",
                    value: expense.currencyText(code: baseCurrencyCode),
                    icon: "arrow.up.right",
                    tint: ReadablePalette.expenseAccent
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: shadowColor, radius: 14, x: 0, y: 10)
    }
}

private struct ExchangeRateStatusCard: View {
    let rate: Double
    let lastUpdated: Date?
    let sourceName: String
    let isLoading: Bool
    let errorMessage: String?
    let providerPreference: ExchangeRateProviderPreference
    let hasBanxicoToken: Bool
    let onRefreshTap: () -> Void

    private struct StatusBadge {
        let text: String
        let foreground: Color
        let background: Color
    }

    private var lastUpdatedText: String {
        guard let lastUpdated else { return "Sin actualizar" }
        return lastUpdated.formatted(
            .dateTime
                .locale(Locale(identifier: "es_MX"))
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
        )
    }

    private var displaySourceName: String {
        switch sourceName {
        case "banxico":
            return "Banxico"
        case "open.er-api":
            return "OpenERAPI"
        case "frankfurter":
            return "Frankfurter"
        default:
            return sourceName
        }
    }

    private var banxicoStatusBadge: StatusBadge? {
        switch providerPreference {
        case .banxico:
            if isLoading {
                return StatusBadge(
                    text: "Validando Banxico...",
                    foreground: AppPalette.Finance.c800,
                    background: AppPalette.Finance.c100
                )
            }
            if !hasBanxicoToken {
                return StatusBadge(
                    text: "Falta token Banxico",
                    foreground: Color(red: 0.73, green: 0.42, blue: 0.09),
                    background: Color(red: 1.0, green: 0.95, blue: 0.83)
                )
            }
            if sourceName == "banxico" && errorMessage == nil {
                return StatusBadge(
                    text: "Banxico conectado",
                    foreground: Color(red: 0.06, green: 0.55, blue: 0.27),
                    background: Color(red: 0.88, green: 0.98, blue: 0.91)
                )
            }
            if let errorMessage, errorMessage.localizedCaseInsensitiveContains("token") {
                return StatusBadge(
                    text: "Token Banxico invalido",
                    foreground: Color.financeExpenseAccent,
                    background: Color(red: 1.0, green: 0.90, blue: 0.90)
                )
            }
            return StatusBadge(
                text: "Banxico no disponible",
                foreground: Color(red: 0.73, green: 0.42, blue: 0.09),
                background: Color(red: 1.0, green: 0.95, blue: 0.83)
            )

        case .automatic:
            if sourceName == "banxico" && errorMessage == nil {
                return StatusBadge(
                    text: "Banxico conectado",
                    foreground: Color(red: 0.06, green: 0.55, blue: 0.27),
                    background: Color(red: 0.88, green: 0.98, blue: 0.91)
                )
            }
            if hasBanxicoToken && sourceName != "banxico" {
                return StatusBadge(
                    text: "Banxico no disponible (respaldo activo)",
                    foreground: Color(red: 0.73, green: 0.42, blue: 0.09),
                    background: Color(red: 1.0, green: 0.95, blue: 0.83)
                )
            }
            return nil

        case .openERAPI, .frankfurter:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label("Tipo de cambio", systemImage: "dollarsign.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .fontDesign(.rounded)

                Spacer()

                Button(action: onRefreshTap) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isLoading ? "Actualizando" : "Actualizar")
                            .font(.caption.weight(.semibold))
                            .fontDesign(.rounded)
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.Finance.c700)
                .disabled(isLoading)
            }

            Text("1 USD = \(rate.formatted(.number.precision(.fractionLength(4)))) MXN")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            if let badge = banxicoStatusBadge {
                Text(badge.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badge.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(badge.background, in: Capsule())
            }

            HStack(spacing: 8) {
                Text("Actualizado: \(lastUpdatedText)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer(minLength: 8)

                Text(displaySourceName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.Finance.c800)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppPalette.Finance.c100.opacity(0.85), in: Capsule())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.financeExpenseAccent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ReadablePalette.cardBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct AccountsOverview: View {
    let accounts: [Account]
    let balanceForAccount: (Account) -> Double
    let baseCurrencyCode: String
    private var columns: [GridItem] {
        let count = max(1, min(accounts.count, 3))
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cuentas")
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(accounts, id: \.id) { account in
                    AccountBalancePill(
                        account: account,
                        balance: balanceForAccount(account),
                        baseCurrencyCode: baseCurrencyCode
                    )
                }
            }
        }
    }
}

private struct AccountBalancePill: View {
    let account: Account
    let balance: Double
    let baseCurrencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: account.type.icon)
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.13, green: 0.49, blue: 0.89))
                Text(account.name)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.rounded)
            }

            Text(balance.currencyText(code: baseCurrencyCode))
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(balance >= 0 ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct FixedTransactionsOverview: View {
    let entries: [FixedTransaction]
    let fixedIncome: Double
    let fixedExpense: Double
    let onAddTap: () -> Void
    let onEditTap: (FixedTransaction) -> Void
    let onDeleteTap: (FixedTransaction) -> Void

    private var sortedEntries: [FixedTransaction] {
        entries.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Movimientos fijos")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            HStack(spacing: 8) {
                FixedSummaryPill(
                    title: "Ingreso fijo",
                    value: fixedIncome.currencyText,
                    tint: ReadablePalette.incomeAccent
                )

                FixedSummaryPill(
                    title: "Gasto fijo",
                    value: fixedExpense.currencyText,
                    tint: ReadablePalette.expenseAccent
                )
            }

            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sin movimientos fijos")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    Text("Registra pagos o ingresos recurrentes que se repiten cada mes.")
                        .font(.caption)
                        .foregroundStyle(ReadablePalette.secondaryText)
                    Button("Agregar fijo") {
                        onAddTap()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.10, green: 0.61, blue: 0.37))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedEntries, id: \.id) { entry in
                        FixedTransactionRow(
                            entry: entry,
                            onEditTap: { onEditTap(entry) },
                            onDeleteTap: { onDeleteTap(entry) }
                        )
                    }
                }
            }
        }
    }
}

private struct FixedSummaryPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ReadablePalette.secondaryText)

            Text(value)
                .font(.caption.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct FixedTransactionRow: View {
    let entry: FixedTransaction
    let onEditTap: () -> Void
    let onDeleteTap: () -> Void

    private var accentColor: Color {
        switch entry.type {
        case .income:
            return ReadablePalette.incomeAccent
        case .expense, .transfer:
            return ReadablePalette.expenseAccent
        }
    }

    private var typeIcon: String {
        switch entry.type {
        case .income:
            return "arrow.down.left"
        case .expense, .transfer:
            return "arrow.up.right"
        }
    }

    private var signedAmount: String {
        switch entry.type {
        case .income:
            return "+" + entry.amount.currencyText
        case .expense, .transfer:
            return "-" + entry.amount.currencyText
        }
    }

    private var activeText: String {
        entry.isActive ? "Activo" : "Pausado"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                onEditTap()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: typeIcon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(entry.isActive ? .primary : ReadablePalette.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(entry.category)
                            Text("·")
                            Text("Dia \(entry.dayOfMonth)")
                            Text("·")
                            Text(activeText)
                        }
                        .font(.caption)
                        .foregroundStyle(ReadablePalette.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(signedAmount)
                    .font(.subheadline.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(accentColor)

                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)

                    Button(role: .destructive) {
                        onDeleteTap()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .padding(6)
                            .background(Color.red.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct BudgetsOverview: View {
    let budgets: [CategoryBudget]
    let spentForBudget: (CategoryBudget) -> Double
    let onAddTap: () -> Void
    let onDeleteTap: (CategoryBudget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Presupuestos del mes")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            if budgets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sin presupuestos configurados")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    Text("Define un limite por categoria para controlar tus gastos de este mes.")
                        .font(.caption)
                        .foregroundStyle(ReadablePalette.secondaryText)
                    Button("Crear presupuesto") {
                        onAddTap()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                        .tint(AppPalette.Finance.c600)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(budgets, id: \.id) { budget in
                        BudgetProgressRow(
                            budget: budget,
                            spent: spentForBudget(budget),
                            onDeleteTap: { onDeleteTap(budget) }
                        )
                    }
                }
            }
        }
    }
}

private struct BudgetProgressRow: View {
    let budget: CategoryBudget
    let spent: Double
    let onDeleteTap: () -> Void

    private var progress: Double {
        guard budget.amountLimit > 0 else { return 0 }
        return spent / budget.amountLimit
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var statusText: String {
        if progress >= 1 { return "Excedido" }
        if progress >= 0.8 { return "Cerca del limite" }
        return "En rango"
    }

    private var statusColor: Color {
        if progress >= 1 { return .red }
        if progress >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: CategoryCatalog.icon(for: budget.category, type: .expense))
                        .foregroundStyle(ReadablePalette.expenseAccent)
                    Text(budget.category)
                }
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)

                Spacer()

                Text("\(spent.currencyText) / \(budget.amountLimit.currencyText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)

                Button(role: .destructive) {
                    onDeleteTap()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .padding(6)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: clampedProgress)
                .tint(statusColor)

            HStack {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Text("\((progress * 100).formatted(.number.precision(.fractionLength(0))))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }
        }
        .padding(12)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct SheetBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [AppPalette.Finance.c950, AppPalette.Finance.c900]
                : [AppPalette.Finance.c50, AppPalette.Finance.c100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 16)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppPalette.Finance.c400.opacity(colorScheme == .dark ? 0.10 : 0.15))
                .frame(width: 240, height: 240)
                .blur(radius: 18)
                .offset(x: 140, y: 290)
        }
    }
}

private struct SheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(14)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
    }
}

private struct SheetInputRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var field: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ReadablePalette.secondaryText)

            field
                .padding(10)
                .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private enum FixedEntryType: String, CaseIterable, Identifiable {
    case income = "Ingreso"
    case expense = "Gasto"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .income:
            return ReadablePalette.incomeAccent
        case .expense:
            return ReadablePalette.expenseAccent
        }
    }

    var transactionType: TransactionType {
        switch self {
        case .income:
            return .income
        case .expense:
            return .expense
        }
    }

    var options: [CategoryOption] {
        CategoryCatalog.options(for: transactionType)
    }

    static func from(_ type: TransactionType) -> FixedEntryType {
        type == .income ? .income : .expense
    }
}

private struct FixedTransactionPayload {
    let title: String
    let category: String
    let amount: Double
    let dayOfMonth: Int
    let type: TransactionType
    let isActive: Bool
}

private struct AddFixedTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    let initialEntry: FixedTransaction?
    let onSave: (FixedTransactionPayload) -> Void
    let onDelete: (() -> Void)?

    @State private var title = ""
    @State private var category = ""
    @State private var amountText = ""
    @State private var dayOfMonth = 1
    @State private var entryType: FixedEntryType = .expense
    @State private var isActive = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteAlert = false

    private var isEditing: Bool {
        initialEntry != nil
    }

    private var accent: Color {
        entryType.accent
    }

    private var categoryOptions: [CategoryOption] {
        entryType.options
    }

    private var selectedCategory: String {
        if categoryOptions.contains(where: { $0.name == category }) {
            return category
        }
        return categoryOptions.first?.name ?? "Otros"
    }

    private var selectedCategoryIcon: String {
        CategoryCatalog.icon(for: selectedCategory, type: entryType.transactionType)
    }

    private var selectedCategoryColor: Color {
        CategoryCatalog.color(for: selectedCategory, type: entryType.transactionType)
    }

    private var canSave: Bool {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanedTitle.isEmpty && parsedAmount > 0
    }

    private var parsedAmount: Double {
        let normalized = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackgroundView(accent: accent)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SheetCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tipo")
                                    .font(.subheadline.weight(.semibold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                Picker("Tipo", selection: $entryType) {
                                    ForEach(FixedEntryType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(accent)

                                SheetInputRow(icon: "textformat", title: "Nombre") {
                                    TextField("", text: $title)
                                        .textInputAutocapitalization(.sentences)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Label {
                                        Text("Categoria")
                                    } icon: {
                                        Image(systemName: selectedCategoryIcon)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                    Menu {
                                        ForEach(categoryOptions, id: \.id) { option in
                                            Button {
                                                category = option.name
                                            } label: {
                                                HStack {
                                                    Image(systemName: option.icon)
                                                        .foregroundStyle(option.color)
                                                    Text(option.name)
                                                    Spacer()
                                                    if option.name == selectedCategory {
                                                        Image(systemName: "checkmark")
                                                            .font(.caption.weight(.bold))
                                                            .foregroundStyle(accent)
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: selectedCategoryIcon)
                                                .foregroundStyle(selectedCategoryColor)
                                            Text(selectedCategory)
                                                .font(.subheadline.weight(.semibold))
                                                .fontDesign(.rounded)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(accent)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                        .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(accent.opacity(0.25), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                SheetInputRow(icon: "banknote", title: "Monto mensual") {
                                    TextField("", text: $amountText)
                                        .keyboardType(.decimalPad)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Label {
                                        Text("Dia de cobro/pago")
                                    } icon: {
                                        Image(systemName: "calendar")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                    HStack {
                                        Stepper(value: $dayOfMonth, in: 1...31) {
                                            Text("Dia \(dayOfMonth)")
                                                .font(.subheadline.weight(.semibold))
                                                .fontDesign(.rounded)
                                        }
                                        .tint(accent)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                Toggle("Activo", isOn: $isActive)
                                    .font(.subheadline.weight(.semibold))
                                    .tint(accent)
                            }
                        }

                        if isEditing, onDelete != nil {
                            SheetCard {
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Label("Eliminar fijo", systemImage: "trash.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.90, green: 0.20, blue: 0.22))
                            }
                        }

                        Button {
                            saveEntry()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(isEditing ? "Actualizar fijo" : "Guardar fijo")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: accent.opacity(0.35), radius: 10, x: 0, y: 6)
                            .opacity(canSave ? 1 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(isEditing ? "Editar fijo" : "Nuevo fijo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { saveEntry() }
                        .disabled(!canSave)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Eliminar fijo", isPresented: $showDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Este movimiento fijo se eliminara.")
            }
            .onAppear {
                ensureValidCategory()
            }
            .onChange(of: entryType) { _, _ in
                ensureValidCategory()
            }
        }
    }

    private func saveEntry() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            alertMessage = "Ingresa un nombre."
            showAlert = true
            return
        }

        guard parsedAmount > 0 else {
            alertMessage = "Ingresa un monto valido mayor que cero."
            showAlert = true
            return
        }

        onSave(
            FixedTransactionPayload(
                title: cleanedTitle,
                category: selectedCategory,
                amount: parsedAmount,
                dayOfMonth: dayOfMonth,
                type: entryType.transactionType,
                isActive: isActive
            )
        )
        dismiss()
    }

    private func ensureValidCategory() {
        if !categoryOptions.contains(where: { $0.name == category }) {
            category = categoryOptions.first?.name ?? "Otros"
        }
    }

    init(
        initialEntry: FixedTransaction? = nil,
        onSave: @escaping (FixedTransactionPayload) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initialEntry = initialEntry
        self.onSave = onSave
        self.onDelete = onDelete

        if let initialEntry {
            _title = State(initialValue: initialEntry.title)
            _category = State(initialValue: initialEntry.category)
            _amountText = State(initialValue: initialEntry.amount.formatted(.number.precision(.fractionLength(0...2))))
            _dayOfMonth = State(initialValue: initialEntry.dayOfMonth)
            _entryType = State(initialValue: FixedEntryType.from(initialEntry.type))
            _isActive = State(initialValue: initialEntry.isActive)
        }
    }
}

private struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingBudgets: [CategoryBudget]
    let expenseCategories: [String]

    @State private var selectedCategory = ""
    @State private var amountText = ""
    @State private var monthDate = Date.now
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var selectedMonth: Int {
        Calendar.current.component(.month, from: monthDate)
    }

    private var selectedYear: Int {
        Calendar.current.component(.year, from: monthDate)
    }

    private var canSave: Bool {
        !selectedCategory.isEmpty && (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var accent: Color {
        Color(red: 0.13, green: 0.49, blue: 0.89)
    }

    private var activeCategory: String {
        if selectedCategory.isEmpty {
            return expenseCategories.first ?? "Otros"
        }
        return selectedCategory
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackgroundView(accent: accent)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SheetCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Categoria")
                                    .font(.subheadline.weight(.semibold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                Menu {
                                    ForEach(expenseCategories, id: \.self) { category in
                                        Button {
                                            selectedCategory = category
                                        } label: {
                                            HStack {
                                                Image(systemName: CategoryCatalog.icon(for: category, type: .expense))
                                                    .foregroundStyle(accent)
                                                Text(category)
                                                Spacer()
                                                if category == activeCategory {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(accent)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: CategoryCatalog.icon(for: activeCategory, type: .expense))
                                            .foregroundStyle(accent)

                                        Text(activeCategory)
                                            .font(.subheadline.weight(.semibold))
                                            .fontDesign(.rounded)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(accent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(accent.opacity(0.25), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        SheetCard {
                            VStack(spacing: 12) {
                                SheetInputRow(icon: "banknote", title: "Limite mensual") {
                                    TextField("", text: $amountText)
                                        .keyboardType(.decimalPad)
                                }

                                DatePicker("Mes", selection: $monthDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .fontDesign(.rounded)
                            }
                        }

                        Button {
                            saveBudget()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar presupuesto")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: accent.opacity(0.35), radius: 10, x: 0, y: 6)
                            .opacity(canSave ? 1 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Nuevo presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { saveBudget() }
                        .disabled(!canSave)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if selectedCategory.isEmpty {
                    selectedCategory = expenseCategories.first ?? "Otros"
                }
            }
        }
    }

    private func saveBudget() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            alertMessage = "Ingresa un monto valido mayor que cero."
            showAlert = true
            return
        }

        let duplicate = existingBudgets.contains {
            $0.category == selectedCategory &&
            $0.month == selectedMonth &&
            $0.year == selectedYear
        }

        guard !duplicate else {
            alertMessage = "Ya existe un presupuesto para esa categoria en ese mes."
            showAlert = true
            return
        }

        let budget = CategoryBudget(
            category: selectedCategory,
            amountLimit: amount,
            month: selectedMonth,
            year: selectedYear
        )

        modelContext.insert(budget)
        dismiss()
    }
}

private struct SavingsGoalsOverview: View {
    let goals: [SavingsGoal]
    let onAddTap: () -> Void
    let onAddContributionTap: (SavingsGoal) -> Void
    let onDeleteTap: (SavingsGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Metas de ahorro")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            if goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sin metas de ahorro")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                    Text("Define una meta y empieza a sumar abonos para seguir tu progreso.")
                        .font(.caption)
                        .foregroundStyle(ReadablePalette.secondaryText)
                    Button("Crear meta") {
                        onAddTap()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                        .tint(Color(red: 0.08, green: 0.67, blue: 0.47))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appStrokeSoft, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(goals, id: \.id) { goal in
                        SavingsGoalProgressRow(
                            goal: goal,
                            onAddContributionTap: { onAddContributionTap(goal) },
                            onDeleteTap: { onDeleteTap(goal) }
                        )
                    }
                }
            }
        }
    }
}

private struct SavingsGoalProgressRow: View {
    let goal: SavingsGoal
    let onAddContributionTap: () -> Void
    let onDeleteTap: () -> Void

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return goal.savedAmount / goal.targetAmount
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var progressText: String {
        "\((clampedProgress * 100).formatted(.number.precision(.fractionLength(0))))%"
    }

    private var remainingAmount: Double {
        max(goal.targetAmount - goal.savedAmount, 0)
    }

    private var statusColor: Color {
        if progress >= 1 { return .green }
        if progress >= 0.75 { return .orange }
        return Color(red: 0.13, green: 0.49, blue: 0.89)
    }

    private var statusText: String {
        if progress >= 1 { return "Meta cumplida" }
        if progress >= 0.75 { return "Ya casi llegas" }
        return "En progreso"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)

                Spacer()

                Text("\(goal.savedAmount.currencyText) / \(goal.targetAmount.currencyText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            ProgressView(value: clampedProgress)
                .tint(statusColor)

            HStack {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)

                Spacer()

                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            HStack(spacing: 10) {
                Text("Faltan \(remainingAmount.currencyText)")
                    .font(.caption)
                    .foregroundStyle(ReadablePalette.secondaryText)

                Spacer()

                Button {
                    onAddContributionTap()
                } label: {
                    Label("Abonar", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    onDeleteTap()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .padding(6)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingGoals: [SavingsGoal]

    @State private var title = ""
    @State private var targetAmountText = ""
    @State private var currentAmountText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = Double(targetAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let saved = Double(currentAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return !trimmedTitle.isEmpty && target > 0 && saved >= 0
    }

    private var accent: Color {
        Color(red: 0.08, green: 0.67, blue: 0.47)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackgroundView(accent: accent)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SheetCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Nombre de la meta")
                                    .font(.subheadline.weight(.semibold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                TextField("", text: $title)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .padding(10)
                                    .background(ReadablePalette.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        SheetCard {
                            VStack(spacing: 12) {
                                SheetInputRow(icon: "target", title: "Objetivo") {
                                    TextField("", text: $targetAmountText)
                                        .keyboardType(.decimalPad)
                                }

                                SheetInputRow(icon: "wallet.pass", title: "Ahorro actual") {
                                    TextField("", text: $currentAmountText)
                                        .keyboardType(.decimalPad)
                                }
                            }
                        }

                        Button {
                            saveGoal()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar meta")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: accent.opacity(0.35), radius: 10, x: 0, y: 6)
                            .opacity(canSave ? 1 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Nueva meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { saveGoal() }
                        .disabled(!canSave)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            alertMessage = "Ingresa un nombre para la meta."
            showAlert = true
            return
        }

        guard let target = Double(targetAmountText.replacingOccurrences(of: ",", with: ".")), target > 0 else {
            alertMessage = "Ingresa un objetivo valido mayor que cero."
            showAlert = true
            return
        }

        let saved = Double(currentAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard saved >= 0 else {
            alertMessage = "El ahorro actual no puede ser negativo."
            showAlert = true
            return
        }

        let duplicate = existingGoals.contains {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedTitle.lowercased()
        }
        guard !duplicate else {
            alertMessage = "Ya existe una meta con ese nombre."
            showAlert = true
            return
        }

        let goal = SavingsGoal(
            title: trimmedTitle,
            targetAmount: target,
            savedAmount: saved
        )
        modelContext.insert(goal)
        dismiss()
    }
}

private struct AddGoalContributionView: View {
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal

    @State private var amountText = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var canSave: Bool {
        (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var accent: Color {
        Color(red: 0.08, green: 0.67, blue: 0.47)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackgroundView(accent: accent)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SheetCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Meta")
                                    .font(.subheadline.weight(.semibold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(ReadablePalette.secondaryText)

                                HStack(alignment: .firstTextBaseline) {
                                    Text(goal.title)
                                        .font(.subheadline.weight(.semibold))
                                        .fontDesign(.rounded)
                                    Spacer()
                                    Text(goal.savedAmount.currencyText)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ReadablePalette.secondaryText)
                                }

                                HStack {
                                    Text("Objetivo")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ReadablePalette.secondaryText)
                                    Spacer()
                                    Text(goal.targetAmount.currencyText)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ReadablePalette.secondaryText)
                                }
                            }
                        }

                        SheetCard {
                            SheetInputRow(icon: "banknote", title: "Nuevo abono") {
                                TextField("", text: $amountText)
                                    .keyboardType(.decimalPad)
                            }
                        }

                        Button {
                            saveContribution()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Guardar abono")
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: accent.opacity(0.35), radius: 10, x: 0, y: 6)
                            .opacity(canSave ? 1 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Abonar ahorro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { saveContribution() }
                        .disabled(!canSave)
                }
            }
            .alert("No se puede guardar", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveContribution() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            alertMessage = "Ingresa un monto valido mayor que cero."
            showAlert = true
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            goal.savedAmount += amount
        }
        dismiss()
    }
}

private struct ReportsOverview: View {
    @Binding var selectedRange: ReportRange

    let periodTitle: String
    let income: Double
    let expense: Double
    let balance: Double
    let transactionCount: Int
    let topExpenseCategories: [CategoryExpenseSummary]
    let baseCurrencyCode: String

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reporte financiero")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ReadablePalette.secondaryText)

                Spacer()

                Text(periodTitle.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            Picker("Periodo", selection: $selectedRange) {
                ForEach(ReportRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 8) {
                ReportMetricCard(
                    title: "Ingresos",
                    value: income.currencyText(code: baseCurrencyCode),
                    icon: "arrow.down.left",
                    tint: ReadablePalette.incomeAccent
                )
                ReportMetricCard(
                    title: "Gastos",
                    value: expense.currencyText(code: baseCurrencyCode),
                    icon: "arrow.up.right",
                    tint: ReadablePalette.expenseAccent
                )
                ReportMetricCard(
                    title: "Balance",
                    value: balance.currencyText(code: baseCurrencyCode),
                    icon: "chart.line.uptrend.xyaxis",
                    tint: balance >= 0 ? Color(red: 0.10, green: 0.61, blue: 0.87) : .orange
                )
                ReportMetricCard(
                    title: "Movimientos",
                    value: "\(transactionCount)",
                    icon: "list.bullet.rectangle",
                    tint: Color(red: 0.36, green: 0.44, blue: 0.80)
                )
            }

            if topExpenseCategories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sin gastos en este periodo")
                        .font(.caption.weight(.semibold))
                    Text("Agrega movimientos de tipo gasto para ver el desglose por categoria.")
                        .font(.caption2)
                        .foregroundStyle(ReadablePalette.secondaryText)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top categorias de gasto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)

                    ForEach(topExpenseCategories) { item in
                        CategoryExpenseBarRow(item: item, currencyCode: baseCurrencyCode)
                    }
                }
            }
        }
        .padding(12)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct MonthComparisonOverview: View {
    let currentMonthTitle: String
    let previousMonthTitle: String

    let currentIncome: Double
    let previousIncome: Double
    let incomeDeltaPercent: Double?

    let currentExpense: Double
    let previousExpense: Double
    let expenseDeltaPercent: Double?

    let currentBalance: Double
    let previousBalance: Double
    let balanceDeltaPercent: Double?

    let currentMovements: Int
    let previousMovements: Int
    let movementDeltaPercent: Double?
    let baseCurrencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mes actual vs mes anterior")
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(ReadablePalette.secondaryText)

            HStack {
                Text(currentMonthTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundStyle(ReadablePalette.secondaryText)
                Text(previousMonthTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            VStack(spacing: 8) {
                MonthComparisonMetricRow(
                    title: "Ingresos",
                    currentValue: currentIncome.currencyText(code: baseCurrencyCode),
                    previousValue: previousIncome.currencyText(code: baseCurrencyCode),
                    deltaPercent: incomeDeltaPercent,
                    trendMode: .upIsGood
                )

                MonthComparisonMetricRow(
                    title: "Gastos",
                    currentValue: currentExpense.currencyText(code: baseCurrencyCode),
                    previousValue: previousExpense.currencyText(code: baseCurrencyCode),
                    deltaPercent: expenseDeltaPercent,
                    trendMode: .downIsGood
                )

                MonthComparisonMetricRow(
                    title: "Balance",
                    currentValue: currentBalance.currencyText(code: baseCurrencyCode),
                    previousValue: previousBalance.currencyText(code: baseCurrencyCode),
                    deltaPercent: balanceDeltaPercent,
                    trendMode: .upIsGood
                )

                MonthComparisonMetricRow(
                    title: "Movimientos",
                    currentValue: "\(currentMovements)",
                    previousValue: "\(previousMovements)",
                    deltaPercent: movementDeltaPercent,
                    trendMode: .neutral
                )
            }
        }
        .padding(12)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct MonthComparisonMetricRow: View {
    enum TrendMode {
        case upIsGood
        case downIsGood
        case neutral
    }

    let title: String
    let currentValue: String
    let previousValue: String
    let deltaPercent: Double?
    let trendMode: TrendMode

    private var deltaText: String {
        guard let deltaPercent else { return "Nuevo" }
        let sign = deltaPercent > 0 ? "+" : ""
        return "\(sign)\(deltaPercent.formatted(.number.precision(.fractionLength(1))))%"
    }

    private var deltaIcon: String {
        guard let deltaPercent else { return "sparkles" }
        if deltaPercent > 0 { return "arrow.up.right" }
        if deltaPercent < 0 { return "arrow.down.right" }
        return "minus"
    }

    private var deltaColor: Color {
        guard let deltaPercent else { return Color(red: 0.13, green: 0.49, blue: 0.89) }

        switch trendMode {
        case .upIsGood:
            if deltaPercent > 0 { return .green }
            if deltaPercent < 0 { return .red }
            return .secondary
        case .downIsGood:
            if deltaPercent == 0 { return .secondary }
            return ReadablePalette.expenseAccent
        case .neutral:
            return Color(red: 0.13, green: 0.49, blue: 0.89)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)

                Spacer()

                Label(deltaText, systemImage: deltaIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(deltaColor)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Actual:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)
                    Text(currentValue)
                        .font(.caption.weight(.semibold))
                }

                HStack(spacing: 4) {
                    Text("Anterior:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ReadablePalette.secondaryText)
                    Text(previousValue)
                        .font(.caption.weight(.semibold))
                }

                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ReportMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            Text(value)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct CategoryExpenseBarRow: View {
    let item: CategoryExpenseSummary
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: CategoryCatalog.icon(for: item.category, type: .expense))
                        .foregroundStyle(ReadablePalette.expenseAccent)
                    Text(item.category)
                }
                .font(.caption.weight(.semibold))
                Spacer()
                Text(item.amount.currencyText(code: currencyCode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadablePalette.secondaryText)
            }

            GeometryReader { proxy in
                let progressWidth = max(proxy.size.width * item.ratio, 4)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ReadablePalette.expenseAccent,
                                    ReadablePalette.expenseAccent.opacity(0.72)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct MetricPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let icon: String
    let tint: Color

    init(_ title: String, value: String, icon: String, tint: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ReadablePalette.onDarkSecondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            .white.opacity(colorScheme == .dark ? 0.16 : 0.23),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private struct FilterBar: View {
    @Binding var selectedFilter: TransactionFilter

    private func accentColor(for filter: TransactionFilter) -> Color {
        switch filter {
        case .all:
            return ReadablePalette.financeAccent
        case .income:
            return ReadablePalette.incomeAccent
        case .expense:
            return ReadablePalette.expenseAccent
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TransactionFilter.allCases) { filter in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedFilter = filter
                    }
                } label: {
                    let selectedStyle = AnyShapeStyle(Color.appSurface)
                    let defaultStyle = AnyShapeStyle(Color.appField.opacity(0.92))
                    let selectedAccent = accentColor(for: filter)

                    HStack(spacing: 6) {
                        Image(systemName: filter.icon)
                        Text(filter.rawValue)
                    }
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(
                        selectedFilter == filter
                        ? selectedAccent
                        : ReadablePalette.filterInactiveText
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedFilter == filter ? selectedStyle : defaultStyle,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selectedFilter == filter
                                ? selectedAccent.opacity(0.25)
                                : .clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EmptyStateCard: View {
    let onAddTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppPalette.Finance.c600)

            Text("Sin movimientos todavia")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text("Registra tu primer ingreso o gasto para empezar a visualizar tu balance.")
                .font(.subheadline)
                .foregroundStyle(ReadablePalette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                onAddTap()
            } label: {
                Label("Agregar movimiento", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                AppPalette.Finance.c700,
                                AppPalette.Finance.c500
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct TransactionCard: View {
    let transaction: Transaction
    let onDelete: () -> Void

    private var amountText: String {
        "\(transaction.amount.currencyText(code: transaction.currency.code)) \(transaction.currency.code)"
    }

    private var accentColor: Color {
        switch transaction.type {
        case .income:
            return ReadablePalette.incomeAccent
        case .expense:
            return ReadablePalette.expenseAccent
        case .transfer:
            return ReadablePalette.transferAccent
        }
    }

    private var typeIcon: String {
        switch transaction.type {
        case .income:
            return "arrow.down.left"
        case .expense:
            return "arrow.up.right"
        case .transfer:
            return "arrow.left.arrow.right"
        }
    }

    private var signedAmount: String {
        switch transaction.type {
        case .income:
            return "+" + amountText
        case .expense:
            return "-" + amountText
        case .transfer:
            return "↔ " + amountText
        }
    }

    private var categoryText: String {
        switch transaction.type {
        case .income, .expense:
            if let accountName = transaction.account?.name {
                return "\(transaction.category) · \(accountName)"
            }
            return transaction.category
        case .transfer:
            let source = transaction.sourceAccount?.name ?? "Origen"
            let destination = transaction.destinationAccount?.name ?? "Destino"
            return "\(source) -> \(destination)"
        }
    }

    private var categoryIcon: String {
        switch transaction.type {
        case .income, .expense:
            return CategoryCatalog.icon(for: transaction.category, type: transaction.type)
        case .transfer:
            return CategoryCatalog.transferOption.icon
        }
    }

    private var categoryAccentColor: Color {
        switch transaction.type {
        case .income:
            return CategoryCatalog.color(for: transaction.category, type: .income)
        case .expense:
            return ReadablePalette.expenseAccent
        case .transfer:
            return ReadablePalette.transferAccent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: typeIcon)
                        .font(.subheadline.bold())
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(transaction.title)
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)

                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: categoryIcon)
                                .foregroundStyle(categoryAccentColor)
                            Text(categoryText)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.11), in: Capsule())

                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(ReadablePalette.secondaryText)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 7) {
                    Text(signedAmount)
                        .font(.headline.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(accentColor)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .padding(7)
                            .background(Color.red.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(ReadablePalette.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(ReadablePalette.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private enum CurrencyFormatterStore {
    private static let lock = NSLock()
    private static var formattersByCode: [String: NumberFormatter] = [:]

    static func formatter(for normalizedCode: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }

        if let cached = formattersByCode[normalizedCode] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizedCode
        formatter.maximumFractionDigits = 2
        formattersByCode[normalizedCode] = formatter
        return formatter
    }
}

private extension Double {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var currencyText: String {
        Self.currencyFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    func currencyText(code: String) -> String {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else { return currencyText }
        let formatter = CurrencyFormatterStore.formatter(for: normalizedCode)
        return formatter.string(from: NSNumber(value: self)) ?? "\(self) \(normalizedCode)"
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Transaction.self,
                FixedTransaction.self,
                GymSetRecord.self,
                BodyMeasurementEntry.self,
                Account.self,
                CategoryBudget.self,
                SavingsGoal.self
            ],
            inMemory: true
        )
}
