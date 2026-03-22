//
//  SpendingAnalyzer.swift
//  SpendSense
//

import Foundation

// MARK: - Sendable snapshot (bridge from SwiftData `Transaction`)

struct SpendingTransactionRow: Sendable, Identifiable {
    let id: UUID
    let amount: Double
    let date: Date
    let category: Category
    let merchant: String
    let rawMessageText: String
    let isConfirmed: Bool

    init(
        id: UUID,
        amount: Double,
        date: Date,
        category: Category,
        merchant: String,
        rawMessageText: String,
        isConfirmed: Bool
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.category = category
        self.merchant = merchant
        self.rawMessageText = rawMessageText
        self.isConfirmed = isConfirmed
    }

    init(_ transaction: Transaction) {
        self.id = transaction.id
        self.amount = transaction.amount
        self.date = transaction.date
        self.category = transaction.category
        self.merchant = transaction.merchant
        self.rawMessageText = transaction.rawMessageText
        self.isConfirmed = transaction.isConfirmed
    }
}

// MARK: - Pure calculations (no actor isolation required)

enum SpendingAnalysisCalculator {
    private static let calendar = Calendar(identifier: .gregorian)

    static func totalSpent(rows: [SpendingTransactionRow], in period: DateInterval) -> Double {
        rows
            .filter { period.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    static func spentByCategory(rows: [SpendingTransactionRow], in period: DateInterval) -> [Category: Double] {
        var totals: [Category: Double] = [:]
        for row in rows where period.contains(row.date) {
            totals[row.category, default: 0] += row.amount
        }
        return totals
    }

    static func dailySpend(rows: [SpendingTransactionRow], for month: Date) -> [Date: Double] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        var byDay: [Date: Double] = [:]
        for row in rows where interval.contains(row.date) {
            let day = calendar.startOfDay(for: row.date)
            byDay[day, default: 0] += row.amount
        }
        return byDay
    }

    static func topMerchants(rows: [SpendingTransactionRow], limit: Int, in period: DateInterval) -> [(merchant: String, total: Double)] {
        var totals: [String: Double] = [:]
        for row in rows where period.contains(row.date) {
            let name = row.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            totals[name, default: 0] += row.amount
        }
        return totals
            .map { (merchant: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
            .prefix(max(0, limit))
            .map { $0 }
    }

    static func averageDailySpend(rows: [SpendingTransactionRow], for month: Date) -> Double {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return 0 }
        let total = totalSpent(rows: rows, in: interval)
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 1
        return total / Double(dayCount)
    }

    static func unusualTransactions(rows: [SpendingTransactionRow], thresholdMultiplier: Double = 2.0) -> [SpendingTransactionRow] {
        guard thresholdMultiplier > 0 else { return [] }
        var sumByCategory: [Category: Double] = [:]
        var countByCategory: [Category: Int] = [:]
        for row in rows {
            sumByCategory[row.category, default: 0] += row.amount
            countByCategory[row.category, default: 0] += 1
        }
        var averages: [Category: Double] = [:]
        for category in Category.allCases {
            let count = countByCategory[category, default: 0]
            guard count > 0 else { continue }
            averages[category] = sumByCategory[category, default: 0] / Double(count)
        }
        return rows.filter { row in
            guard let average = averages[row.category], average > 0 else { return false }
            return row.amount > thresholdMultiplier * average
        }
    }

    static func monthOverMonthChange(rows: [SpendingTransactionRow], reference: Date = .now) -> Double {
        guard let thisInterval = calendar.dateInterval(of: .month, for: reference),
              let previousAnchor = calendar.date(byAdding: .month, value: -1, to: reference),
              let previousInterval = calendar.dateInterval(of: .month, for: previousAnchor) else {
            return 0
        }
        let currentTotal = totalSpent(rows: rows, in: thisInterval)
        let previousTotal = totalSpent(rows: rows, in: previousInterval)
        guard previousTotal > 0 else { return currentTotal > 0 ? 100 : 0 }
        return ((currentTotal - previousTotal) / previousTotal) * 100
    }

    static func subscriptionTotal(rows: [SpendingTransactionRow]) -> Double {
        rows
            .filter { $0.category == .subscriptions }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Actor

/// Thread-safe analyzer over a frozen snapshot of transactions.
///
/// From SwiftData models (typically on MainActor): map to rows, then create the actor:
/// `await SpendingAnalyzer(rows: transactions.map(SpendingTransactionRow.init))`
actor SpendingAnalyzer {
    private let rows: [SpendingTransactionRow]

    init(rows: [SpendingTransactionRow]) {
        self.rows = rows
    }

    func totalSpent(in period: DateInterval) -> Double {
        SpendingAnalysisCalculator.totalSpent(rows: rows, in: period)
    }

    func spentByCategory(in period: DateInterval) -> [Category: Double] {
        SpendingAnalysisCalculator.spentByCategory(rows: rows, in: period)
    }

    func dailySpend(for month: Date) -> [Date: Double] {
        SpendingAnalysisCalculator.dailySpend(rows: rows, for: month)
    }

    func topMerchants(limit: Int, in period: DateInterval) -> [(merchant: String, total: Double)] {
        SpendingAnalysisCalculator.topMerchants(rows: rows, limit: limit, in: period)
    }

    func averageDailySpend(for month: Date) -> Double {
        SpendingAnalysisCalculator.averageDailySpend(rows: rows, for: month)
    }

    func unusualTransactions(thresholdMultiplier: Double = 2.0) -> [Transaction] {
        let unusualRows = SpendingAnalysisCalculator.unusualTransactions(rows: rows, thresholdMultiplier: thresholdMultiplier)
        return unusualRows.map {
            Transaction(
                id: $0.id,
                amount: $0.amount,
                merchant: $0.merchant,
                rawMessageText: $0.rawMessageText,
                date: $0.date,
                category: $0.category,
                isConfirmed: $0.isConfirmed,
                emotionalTag: nil,
                note: nil
            )
        }
    }

    func monthOverMonthChange() -> Double {
        SpendingAnalysisCalculator.monthOverMonthChange(rows: rows)
    }

    func subscriptionTotal() -> Double {
        SpendingAnalysisCalculator.subscriptionTotal(rows: rows)
    }
}

// MARK: - SwiftData convenience

extension SpendingAnalyzer {
    /// Maps `Transaction` models to sendable rows on the MainActor, then creates the analyzer.
    @MainActor
    static func from(transactions: [Transaction]) async -> SpendingAnalyzer {
        let rows = transactions.map(SpendingTransactionRow.init)
        return await SpendingAnalyzer(rows: rows)
    }
}
