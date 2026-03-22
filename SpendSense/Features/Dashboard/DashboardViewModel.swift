//
//  DashboardViewModel.swift
//  SpendSense
//

import Combine
import Foundation
import SwiftData

enum SpendMood: Sendable {
    case underBudget
    case onTrack
    case overSoftGoal
}

struct RhythmDayPoint: Identifiable, Sendable {
    var id: Date { dayStart }
    let dayStart: Date
    let amount: Double
    let dayNumber: Int
}

struct CategorySpendChipModel: Identifiable, Sendable {
    var id: Category { category }
    let category: Category
    let amount: Double
}

struct InsightCardData: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let type: InsightType

    init(id: UUID = UUID(), title: String, body: String, type: InsightType) {
        self.id = id
        self.title = title
        self.body = body
        self.type = type
    }

    init(from insight: SpendingInsight) {
        self.id = insight.id
        self.title = insight.title
        self.body = insight.body
        self.type = insight.type
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published private(set) var isLoading = true

    @Published private(set) var dailyNudge: String = ""
    @Published private(set) var monthlyTotal: Double = 0
    @Published private(set) var softGoal: Double = 25_000
    @Published private(set) var daysLeftInMonth: Int = 0
    @Published private(set) var currentMonthLabel: String = ""
    @Published private(set) var averagePerDayThisMonth: Double = 0
    @Published private(set) var spendMood: SpendMood = .onTrack
    @Published private(set) var ringProgress: Double = 0

    @Published private(set) var rhythmDays: [RhythmDayPoint] = []
    @Published private(set) var maxRhythmAmount: Double = 1

    @Published private(set) var categoryChips: [CategorySpendChipModel] = []
    @Published private(set) var recentTransactions: [Transaction] = []
    @Published private(set) var allTransactions: [Transaction] = []
    @Published private(set) var insights: [InsightCardData] = []

    private let calendar = Calendar(identifier: .gregorian)
    private let insightEngine = InsightEngine()

    func load(modelContext: ModelContext, softMonthlyGoal: Double) async {
        isLoading = true
        await Task.yield()

        softGoal = max(softMonthlyGoal, 1)

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        allTransactions = fetched

        let rows = fetched.map(SpendingTransactionRow.init)
        let now = Date()

        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            isLoading = false
            return
        }

        monthlyTotal = SpendingAnalysisCalculator.totalSpent(rows: rows, in: monthInterval)
        let dayOfMonth = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        daysLeftInMonth = max(0, daysInMonth - dayOfMonth)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        currentMonthLabel = formatter.string(from: now)

        let elapsedDays = max(1, dayOfMonth)
        averagePerDayThisMonth = monthlyTotal / Double(elapsedDays)

        let ratio = monthlyTotal / softGoal
        ringProgress = min(ratio, 1.15)

        if ratio < 0.85 {
            spendMood = .underBudget
        } else if ratio <= 1.0 {
            spendMood = .onTrack
        } else {
            spendMood = .overSoftGoal
        }

        rhythmDays = buildRhythmDays(rows: rows, monthInterval: monthInterval, today: now, daysInMonth: daysInMonth)
        maxRhythmAmount = rhythmDays.map(\.amount).max() ?? 1

        let byCat = SpendingAnalysisCalculator.spentByCategory(rows: rows, in: monthInterval)
        categoryChips = byCat
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { CategorySpendChipModel(category: $0.key, amount: $0.value) }

        recentTransactions = Array(fetched.prefix(5))

        let generated = insightEngine.generateWeeklyInsights(transactions: fetched)
        insights = generated.map(InsightCardData.init(from:))

        dailyNudge = insightEngine.generateDailyNudge(transactions: fetched)

        isLoading = false

        WidgetSnapshotStore.update(monthToDateTotal: monthlyTotal, dailyNudge: dailyNudge)
    }

    func dismissInsight(id: UUID) {
        insights.removeAll { $0.id == id }
    }

    func transactions(on day: Date) -> [Transaction] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return allTransactions.filter { $0.date >= start && $0.date < end }
            .sorted { $0.date > $1.date }
    }

    func transactions(in category: Category) -> [Transaction] {
        allTransactions.filter { $0.category == category }
            .sorted { $0.date > $1.date }
    }

    func confirm(_ transaction: Transaction, modelContext: ModelContext, softMonthlyGoal: Double) async {
        transaction.isConfirmed = true
        try? modelContext.save()
        SpendSenseHaptics.transactionConfirmed()
        await load(modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
    }

    private func buildRhythmDays(
        rows: [SpendingTransactionRow],
        monthInterval: DateInterval,
        today: Date,
        daysInMonth: Int
    ) -> [RhythmDayPoint] {
        var points: [RhythmDayPoint] = []
        let todayStart = calendar.startOfDay(for: today)

        for dayIndex in 0..<daysInMonth {
            guard let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: monthInterval.start) else { continue }
            let start = calendar.startOfDay(for: dayDate)
            if start > todayStart { break }
            let amount = rows
                .filter { calendar.isDate($0.date, inSameDayAs: start) }
                .reduce(0) { $0 + $1.amount }
            let dom = calendar.component(.day, from: start)
            points.append(RhythmDayPoint(dayStart: start, amount: amount, dayNumber: dom))
        }
        return points
    }
}
