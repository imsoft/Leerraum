import Foundation
import SwiftUI
import Combine
import OSLog

struct FinanceDashboardSnapshot {
    var filteredTransactions: [Transaction] = []
    var totalIncome: Double = 0
    var totalExpense: Double = 0
    var balance: Double = 0
    var totalFixedIncome: Double = 0
    var totalFixedExpense: Double = 0
    var currentMonthBudgets: [CategoryBudget] = []
    var reportPeriodTitle: String = ""
    var reportIncome: Double = 0
    var reportExpense: Double = 0
    var reportBalance: Double = 0
    var reportTransactionCount: Int = 0
    var reportTopExpenseCategories: [CategoryExpenseSummary] = []
    var currentMonthComparisonTitle: String = ""
    var previousMonthComparisonTitle: String = ""
    var currentMonthIncomeForComparison: Double = 0
    var previousMonthIncomeForComparison: Double = 0
    var currentMonthExpenseForComparison: Double = 0
    var previousMonthExpenseForComparison: Double = 0
    var currentMonthBalanceForComparison: Double = 0
    var previousMonthBalanceForComparison: Double = 0
    var currentMonthMovementCount: Int = 0
    var previousMonthMovementCount: Int = 0
    var incomeComparisonDeltaPercent: Double?
    var expenseComparisonDeltaPercent: Double?
    var balanceComparisonDeltaPercent: Double?
    var movementComparisonDeltaPercent: Double?
    var expenseCategoriesForBudget: [String] = []
    var spentByBudgetID: [UUID: Double] = [:]
    var accountBalanceByID: [UUID: Double] = [:]

    static let empty = FinanceDashboardSnapshot()
}

@MainActor
final class FinanceDashboardViewModel: ObservableObject {
    @Published private(set) var snapshot: FinanceDashboardSnapshot = .empty

    private struct BudgetSpendKey: Hashable {
        let month: Int
        let year: Int
        let category: String
    }

    func recompute(
        transactions: [Transaction],
        fixedTransactions: [FixedTransaction],
        accounts: [Account],
        budgets: [CategoryBudget],
        selectedFilter: TransactionFilter,
        selectedReportRange: ReportRange,
        usdToMxnRate: Double
    ) {
        let interval = Observability.financeSignposter.beginInterval("finance.viewmodel.recompute")
        defer { Observability.financeSignposter.endInterval("finance.viewmodel.recompute", interval) }
        let calendar = Calendar.current
        let locale = Locale(identifier: "es_MX")
        let now = Date.now

        let reportDateInterval = dateInterval(
            for: selectedReportRange,
            calendar: calendar,
            now: now
        )

        let currentMonthDateInterval = calendar.dateInterval(of: .month, for: now)
            ?? DateInterval(start: now, duration: 0)
        let previousMonthReference = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previousMonthDateInterval = calendar.dateInterval(of: .month, for: previousMonthReference)
            ?? DateInterval(start: previousMonthReference, duration: 0)

        var filteredTransactions: [Transaction] = []

        var totalIncome = 0.0
        var totalExpense = 0.0

        var reportIncome = 0.0
        var reportExpense = 0.0
        var reportTransactionCount = 0
        var reportExpenseByCategory: [String: Double] = [:]

        var currentMonthIncome = 0.0
        var currentMonthExpense = 0.0
        var currentMonthMovementCount = 0

        var previousMonthIncome = 0.0
        var previousMonthExpense = 0.0
        var previousMonthMovementCount = 0

        var accountIncomeByID: [UUID: Double] = [:]
        var accountExpenseByID: [UUID: Double] = [:]
        var accountTransferInByID: [UUID: Double] = [:]
        var accountTransferOutByID: [UUID: Double] = [:]

        var variableExpenseByBudgetKey: [BudgetSpendKey: Double] = [:]
        var expenseCategories = Set(CategoryCatalog.expenseOptions.map(\.name))

        for transaction in transactions {
            if matches(transaction, filter: selectedFilter) {
                filteredTransactions.append(transaction)
            }

            let normalizedAmount = normalizedAmount(for: transaction, usdToMxnRate: usdToMxnRate)

            if reportDateInterval.contains(transaction.date) {
                reportTransactionCount += 1

                switch transaction.type {
                case .income:
                    reportIncome += normalizedAmount
                case .expense:
                    reportExpense += normalizedAmount
                    reportExpenseByCategory[transaction.category, default: 0] += normalizedAmount
                case .transfer:
                    break
                }
            }

            if currentMonthDateInterval.contains(transaction.date) {
                currentMonthMovementCount += 1
                switch transaction.type {
                case .income:
                    currentMonthIncome += normalizedAmount
                case .expense:
                    currentMonthExpense += normalizedAmount
                case .transfer:
                    break
                }
            } else if previousMonthDateInterval.contains(transaction.date) {
                previousMonthMovementCount += 1
                switch transaction.type {
                case .income:
                    previousMonthIncome += normalizedAmount
                case .expense:
                    previousMonthExpense += normalizedAmount
                case .transfer:
                    break
                }
            }

            switch transaction.type {
            case .income:
                totalIncome += normalizedAmount
                add(normalizedAmount, to: transaction.account?.id, in: &accountIncomeByID)
            case .expense:
                totalExpense += normalizedAmount
                add(normalizedAmount, to: transaction.account?.id, in: &accountExpenseByID)

                let budgetKey = BudgetSpendKey(
                    month: calendar.component(.month, from: transaction.date),
                    year: calendar.component(.year, from: transaction.date),
                    category: transaction.category
                )
                variableExpenseByBudgetKey[budgetKey, default: 0] += normalizedAmount
                expenseCategories.insert(transaction.category)
            case .transfer:
                add(normalizedAmount, to: transaction.destinationAccount?.id, in: &accountTransferInByID)
                add(normalizedAmount, to: transaction.sourceAccount?.id, in: &accountTransferOutByID)
            }
        }

        var totalFixedIncome = 0.0
        var totalFixedExpense = 0.0
        var activeFixedExpenseByCategory: [String: Double] = [:]

        for fixedEntry in fixedTransactions {
            if fixedEntry.type == .expense {
                expenseCategories.insert(fixedEntry.category)
            }

            guard fixedEntry.isActive else { continue }

            switch fixedEntry.type {
            case .income:
                totalFixedIncome += fixedEntry.amount
            case .expense:
                totalFixedExpense += fixedEntry.amount
                activeFixedExpenseByCategory[fixedEntry.category, default: 0] += fixedEntry.amount
            case .transfer:
                break
            }
        }

        let currentMonthNumber = calendar.component(.month, from: now)
        let currentYearNumber = calendar.component(.year, from: now)
        let currentMonthBudgets = budgets.filter {
            $0.month == currentMonthNumber && $0.year == currentYearNumber
        }

        var spentByBudgetID: [UUID: Double] = [:]
        for budget in budgets {
            let key = BudgetSpendKey(month: budget.month, year: budget.year, category: budget.category)
            let spent = (variableExpenseByBudgetKey[key] ?? 0) + (activeFixedExpenseByCategory[budget.category] ?? 0)
            spentByBudgetID[budget.id] = spent
        }

        var accountBalanceByID: [UUID: Double] = [:]
        for account in accounts {
            let accountID = account.id
            let computedBalance = account.initialBalance
                + (accountIncomeByID[accountID] ?? 0)
                - (accountExpenseByID[accountID] ?? 0)
                + (accountTransferInByID[accountID] ?? 0)
                - (accountTransferOutByID[accountID] ?? 0)
            accountBalanceByID[accountID] = computedBalance
        }

        let reportTopExpenseCategories = topExpenseCategories(
            groupedAmounts: reportExpenseByCategory,
            totalExpenseAmount: reportExpense
        )

        let currentMonthBalance = currentMonthIncome - currentMonthExpense
        let previousMonthBalance = previousMonthIncome - previousMonthExpense

        snapshot = FinanceDashboardSnapshot(
            filteredTransactions: filteredTransactions,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            balance: totalIncome - totalExpense,
            totalFixedIncome: totalFixedIncome,
            totalFixedExpense: totalFixedExpense,
            currentMonthBudgets: currentMonthBudgets,
            reportPeriodTitle: reportPeriodTitle(
                range: selectedReportRange,
                reportDateInterval: reportDateInterval,
                locale: locale,
                calendar: calendar
            ),
            reportIncome: reportIncome,
            reportExpense: reportExpense,
            reportBalance: reportIncome - reportExpense,
            reportTransactionCount: reportTransactionCount,
            reportTopExpenseCategories: reportTopExpenseCategories,
            currentMonthComparisonTitle: currentMonthDateInterval.start
                .formatted(.dateTime.locale(locale).month(.wide).year())
                .capitalized,
            previousMonthComparisonTitle: previousMonthDateInterval.start
                .formatted(.dateTime.locale(locale).month(.wide).year())
                .capitalized,
            currentMonthIncomeForComparison: currentMonthIncome,
            previousMonthIncomeForComparison: previousMonthIncome,
            currentMonthExpenseForComparison: currentMonthExpense,
            previousMonthExpenseForComparison: previousMonthExpense,
            currentMonthBalanceForComparison: currentMonthBalance,
            previousMonthBalanceForComparison: previousMonthBalance,
            currentMonthMovementCount: currentMonthMovementCount,
            previousMonthMovementCount: previousMonthMovementCount,
            incomeComparisonDeltaPercent: percentageChange(current: currentMonthIncome, previous: previousMonthIncome),
            expenseComparisonDeltaPercent: percentageChange(current: currentMonthExpense, previous: previousMonthExpense),
            balanceComparisonDeltaPercent: percentageChange(current: currentMonthBalance, previous: previousMonthBalance),
            movementComparisonDeltaPercent: percentageChange(
                current: Double(currentMonthMovementCount),
                previous: Double(previousMonthMovementCount)
            ),
            expenseCategoriesForBudget: sortedCategoriesForBudget(expenseCategories),
            spentByBudgetID: spentByBudgetID,
            accountBalanceByID: accountBalanceByID
        )
        Observability.debug(
            Observability.financeLogger,
            "Snapshot recomputed. tx: \(transactions.count), fixed: \(fixedTransactions.count), accounts: \(accounts.count), budgets: \(budgets.count)"
        )
    }

    private func dateInterval(
        for range: ReportRange,
        calendar: Calendar,
        now: Date
    ) -> DateInterval {
        switch range {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
                ?? DateInterval(start: now, duration: 0)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
                ?? DateInterval(start: now, duration: 0)
        case .year:
            return calendar.dateInterval(of: .year, for: now)
                ?? DateInterval(start: now, duration: 0)
        }
    }

    private func reportPeriodTitle(
        range: ReportRange,
        reportDateInterval: DateInterval,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        switch range {
        case .week:
            let start = reportDateInterval.start
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(start.formatted(.dateTime.locale(locale).day().month(.abbreviated))) - \(end.formatted(.dateTime.locale(locale).day().month(.abbreviated)))"
        case .month:
            return reportDateInterval.start.formatted(.dateTime.locale(locale).month(.wide).year())
        case .year:
            return reportDateInterval.start.formatted(.dateTime.year())
        }
    }

    private func matches(_ transaction: Transaction, filter: TransactionFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .income:
            return transaction.type == .income
        case .expense:
            return transaction.type == .expense
        }
    }

    private func normalizedAmount(
        for transaction: Transaction,
        usdToMxnRate: Double
    ) -> Double {
        switch transaction.currency {
        case .mxn:
            return transaction.amount
        case .usd:
            return transaction.amount * usdToMxnRate
        }
    }

    private func add(_ value: Double, to id: UUID?, in dictionary: inout [UUID: Double]) {
        guard let id else { return }
        dictionary[id, default: 0] += value
    }

    private func topExpenseCategories(
        groupedAmounts: [String: Double],
        totalExpenseAmount: Double
    ) -> [CategoryExpenseSummary] {
        groupedAmounts
            .map { category, amount in
                CategoryExpenseSummary(
                    category: category,
                    amount: amount,
                    ratio: totalExpenseAmount > 0 ? amount / totalExpenseAmount : 0
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(4)
            .map { $0 }
    }

    private func sortedCategoriesForBudget(_ categories: Set<String>) -> [String] {
        categories.sorted { lhs, rhs in
            let lhsIsOthers = lhs
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("Otros") == .orderedSame
            let rhsIsOthers = rhs
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("Otros") == .orderedSame

            if lhsIsOthers != rhsIsOthers {
                return !lhsIsOthers
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private func percentageChange(current: Double, previous: Double) -> Double? {
        guard previous != 0 else {
            return current == 0 ? 0 : nil
        }
        return ((current - previous) / abs(previous)) * 100
    }
}
