//
//  SpendingAnalyzerTests.swift
//  SpendSenseTests
//

import Foundation
import Testing
@testable import SpendSense

@Suite("SpendingAnalysisCalculator")
struct SpendingAnalyzerTests {

    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func totalSpentAndSpentByCategory() {
        let monthAnchor = Date()
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else {
            Issue.record("Could not build month interval")
            return
        }
        let day = interval.start
        let rows: [SpendingTransactionRow] = [
            SpendingTransactionRow(
                id: UUID(), amount: 100, date: day, category: .food,
                merchant: "Swiggy", rawMessageText: "", isConfirmed: true
            ),
            SpendingTransactionRow(
                id: UUID(), amount: 200, date: day, category: .food,
                merchant: "Zomato", rawMessageText: "", isConfirmed: true
            ),
            SpendingTransactionRow(
                id: UUID(), amount: 50, date: day, category: .transport,
                merchant: "Uber", rawMessageText: "", isConfirmed: true
            )
        ]
        let total = SpendingAnalysisCalculator.totalSpent(rows: rows, in: interval)
        #expect(total == 350)

        let byCat = SpendingAnalysisCalculator.spentByCategory(rows: rows, in: interval)
        #expect(byCat[.food] == 300)
        #expect(byCat[.transport] == 50)
    }

    @Test
    func unusualTransactionsFlagsLargeVsCategoryAverage() {
        let day = calendar.startOfDay(for: Date())
        var rows: [SpendingTransactionRow] = []
        for _ in 0..<5 {
            rows.append(
                SpendingTransactionRow(
                    id: UUID(), amount: 100, date: day, category: .food,
                    merchant: "Snack", rawMessageText: "", isConfirmed: true
                )
            )
        }
        rows.append(
            SpendingTransactionRow(
                id: UUID(), amount: 400, date: day, category: .food,
                merchant: "Feast", rawMessageText: "", isConfirmed: true
            )
        )
        let unusual = SpendingAnalysisCalculator.unusualTransactions(rows: rows, thresholdMultiplier: 2)
        #expect(unusual.contains { $0.amount == 400 && $0.merchant == "Feast" })
    }

    @Test
    func spendingAnalyzerActorDelegatesToCalculator() async {
        let day = calendar.startOfDay(for: Date())
        guard let interval = calendar.dateInterval(of: .month, for: day) else { return }
        let rows = [
            SpendingTransactionRow(
                id: UUID(), amount: 150, date: day, category: .shopping,
                merchant: "Amazon", rawMessageText: "", isConfirmed: true
            )
        ]
        let analyzer = await SpendingAnalyzer(rows: rows)
        let total = await analyzer.totalSpent(in: interval)
        #expect(total == 150)
        let byCat = await analyzer.spentByCategory(in: interval)
        #expect(byCat[.shopping] == 150)
    }
}
