//
//  InsightEngineGuiltTests.swift
//  SpendSenseTests
//

import Foundation
import Testing
@testable import SpendSense

@Suite("InsightEngine generated copy")
struct InsightEngineGuiltTests {

    @Test @MainActor
    func weeklyInsightsHaveNoGuiltLanguage() {
        let engine = InsightEngine()
        let txs = DeveloperPreviewData.makeSampleTransactions()
        let insights = engine.generateWeeklyInsights(transactions: txs)
        #expect(!insights.isEmpty)
        for ins in insights {
            let combined = ins.title + "\n" + ins.body
            let violation = CopyGuiltTestSupport.firstViolation(in: combined)
            #expect(violation == nil)
        }
    }

    @Test @MainActor
    func monthNarrativeAndDailyNudgeHaveNoGuiltLanguage() {
        let engine = InsightEngine()
        let txs = DeveloperPreviewData.makeSampleTransactions()
        let month = Date()
        let narrative = engine.generateMonthSpendingNarrative(transactions: txs, monthContaining: month)
        #expect(CopyGuiltTestSupport.firstViolation(in: narrative) == nil)

        let nudge = engine.generateDailyNudge(transactions: txs)
        #expect(CopyGuiltTestSupport.firstViolation(in: nudge) == nil)
    }
}
