//
//  InsightsView.swift
//  SpendSense
//

import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(OnboardingStorageKey.softMonthlyGoal) private var softMonthlyGoal = 25_000.0
    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var selectedMonthStart: Date = InsightsCalendar.startOfMonth(for: .now)
    @State private var selectedDonutCategory: Category?
    @State private var donutSelection: String?

    private let calendar = Calendar(identifier: .gregorian)
    private let insightEngine = InsightEngine()

    private var monthOptions: [Date] {
        InsightsCalendar.lastSixMonthStarts(reference: .now, calendar: calendar)
    }

    private var confirmedRows: [SpendingTransactionRow] {
        allTransactions.filter(\.isConfirmed).map(SpendingTransactionRow.init)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if allTransactions.isEmpty {
                        InsightsPatternsEmptyState()
                    }

                    monthPillRow

                    spendingStorySection

                    donutSection

                    weekComparisonSection

                    subscriptionsSection

                    annualProjectionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(SpendSensePalette.groupedBackground(for: colorScheme))
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Month pills

    private var monthPillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(monthOptions, id: \.timeIntervalSince1970) { monthStart in
                    let isSelected = calendar.isDate(monthStart, equalTo: selectedMonthStart, toGranularity: .month)
                    Button {
                        selectedMonthStart = monthStart
                        selectedDonutCategory = nil
                        donutSelection = nil
                    } label: {
                        Text(monthStart.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.22) : Color(.secondarySystemGroupedBackground))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Spending story

    private var spendingStorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spending story")
                .font(.headline)

            Text(insightEngine.generateMonthSpendingNarrative(transactions: allTransactions, monthContaining: selectedMonthStart))
                .font(SpendSenseTypography.text(.body, weight: .regular))
                .lineSpacing(7)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpendSenseLayout.s16 + 2)
                .spendSenseCardSurface(shadow: true)
        }
    }

    // MARK: - Donut

    private var donutSlices: [DonutSlice] {
        guard let interval = calendar.dateInterval(of: .month, for: selectedMonthStart) else { return [] }
        let byCat = SpendingAnalysisCalculator.spentByCategory(rows: confirmedRows, in: interval)
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        return byCat.map { DonutSlice(category: $0.key, amount: $0.value) }
    }

    private var donutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where it went")
                .font(.headline)

            if donutSlices.isEmpty {
                Text("No confirmed spends this month — your donut will fill in when you’re ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(donutSlices) { slice in
                    SectorMark(
                        angle: .value("Spend", slice.amount),
                        innerRadius: .ratio(0.56),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: slice.category.color) ?? .gray)
                    .opacity(
                        selectedDonutCategory == nil || selectedDonutCategory == slice.category ? 1 : 0.38
                    )
                }
                .chartAngleSelection(value: $donutSelection)
                .frame(height: 220)
                .onChange(of: donutSelection) { _, new in
                    syncDonutSelection(new)
                }

                if let cat = selectedDonutCategory,
                   let slice = donutSlices.first(where: { $0.category == cat }),
                   let interval = calendar.dateInterval(of: .month, for: selectedMonthStart) {
                    let total = SpendingAnalysisCalculator.totalSpent(rows: confirmedRows, in: interval)
                    let pct = total > 0 ? (slice.amount / total) * 100 : 0
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cat.emoji) \(cat.displayName)")
                            .font(.subheadline.weight(.semibold))
                        Text("\(SpendSenseCurrency.format(amount: slice.amount, currencyCode: currencyCode)) · \(pct, format: .number.precision(.fractionLength(1)))% of the month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(donutSlices) { slice in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    if selectedDonutCategory == slice.category {
                                        selectedDonutCategory = nil
                                        donutSelection = nil
                                    } else {
                                        selectedDonutCategory = slice.category
                                        donutSelection = slice.selectionKey
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: slice.category.color) ?? .gray)
                                        .frame(width: 10, height: 10)
                                    Text(slice.category.displayName)
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedDonutCategory == slice.category
                                            ? Color.accentColor.opacity(0.15)
                                            : Color(.tertiarySystemGroupedBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func syncDonutSelection(_ key: String?) {
        guard let key, let slice = donutSlices.first(where: { $0.selectionKey == key }) else {
            if donutSelection == nil { selectedDonutCategory = nil }
            return
        }
        selectedDonutCategory = slice.category
    }

    // MARK: - Week cards

    private var weekComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week by week")
                .font(.headline)

            let summaries = weekSummaries(for: selectedMonthStart)
            if summaries.isEmpty {
                Text("Once this month has a few entries, we’ll lay out the weeks here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if let busiest = summaries.max(by: { $0.total < $1.total }),
                   busiest.total > 0 {
                    Text("Week \(busiest.index) had the most movement — not good or bad, just where things clustered.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(summaries) { week in
                        weekCard(week, previous: summaries.first { $0.index == week.index - 1 })
                    }
                }
            }
        }
    }

    private func weekCard(_ week: WeekSpendSummary, previous: WeekSpendSummary?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week \(week.index)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(SpendSenseCurrency.format(amount: week.total, currencyCode: currencyCode))
                .font(SpendSenseTypography.money(.headline, weight: .semibold))
                .monospacedDigit()
            HStack(spacing: 6) {
                if let top = week.topCategory {
                    Text(top.emoji)
                        .font(.title3)
                }
                if let prev = previous, prev.total > 0 {
                    let delta = (week.total - prev.total) / prev.total * 100
                    Image(systemName: week.total >= prev.total ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(week.total >= prev.total
                            ? SpendSenseSemanticColor.elevatedSpendWarm.opacity(0.92)
                            : SpendSenseSemanticColor.onTrack.opacity(0.92))
                    Text("\(abs(delta), format: .number.precision(.fractionLength(0)))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpendSenseLayout.s16 - 2)
        .spendSenseCardSurface(shadow: true)
    }

    private func weekSummaries(for monthStart: Date) -> [WeekSpendSummary] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }
        let monthEnd = monthInterval.end
        var cursor = monthInterval.start
        var segments: [DateInterval] = []
        while segments.count < 4, cursor < monthEnd {
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            let segEnd = next < monthEnd ? next : monthEnd
            if cursor < segEnd {
                segments.append(DateInterval(start: cursor, end: segEnd))
            }
            cursor = segEnd
        }
        return segments.enumerated().map { index, interval in
            let rows = confirmedRows.filter { $0.date >= interval.start && $0.date < interval.end }
            let total = rows.reduce(0) { $0 + $1.amount }
            let byCat = Dictionary(grouping: rows, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            let top = byCat.max(by: { $0.value < $1.value })?.key
            return WeekSpendSummary(index: index + 1, total: total, topCategory: top)
        }
    }

    // MARK: - Subscriptions

    private var subscriptionRows: [SubscriptionAuditRow] {
        SubscriptionAuditBuilder.build(from: allTransactions, calendar: calendar)
    }

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriptions audit")
                .font(.headline)

            if subscriptionRows.isEmpty {
                Text("We’ll surface recurring spends here when subscription-style transactions show up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let combined = subscriptionRows.reduce(0) { $0 + $1.monthlyCostEstimate }
                Text("\(SpendSenseCurrency.format(amount: combined, currencyCode: currencyCode))/month in subscriptions (rough blend across what we’ve seen)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(subscriptionRows) { row in
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(SpendSenseCurrency.format(amount: row.monthlyCostEstimate, currencyCode: currencyCode)) · \(row.monthsDetected) months spotted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Review")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
    }

    // MARK: - Annual projection

    private var annualProjectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year-end vibe check")
                .font(.headline)

            if distinctMonthsWithData < 2 {
                Text("Once we’ve seen at least two months together, we’ll sketch a gentle full-year picture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let avg = averageMonthlyPace(reference: selectedMonthStart)
                let projected = avg * 12
                let cap = 12 * max(softMonthlyGoal, 1)
                let progress = min(1.15, projected / cap)

                Text("Based on your recent pace, you’re on track to spend about \(SpendSenseCurrency.format(amount: projected, currencyCode: currencyCode)) this year — a sketch, not a sentence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.tertiarySystemGroupedBackground))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.35),
                                        Color.accentColor.opacity(0.55)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                .accessibilityLabel("Projected spend versus twelve times your soft monthly goal")

                Text("Soft anchor: \(SpendSenseCurrency.format(amount: cap, currencyCode: currencyCode)) over 12 months — \(SpendSenseCurrency.format(amount: softMonthlyGoal, currencyCode: currencyCode))/mo")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var distinctMonthsWithData: Int {
        var keys = Set<String>()
        for tx in allTransactions where tx.isConfirmed {
            let c = calendar.dateComponents([.year, .month], from: tx.date)
            if let y = c.year, let m = c.month {
                keys.insert("\(y)-\(m)")
            }
        }
        return keys.count
    }

    private func averageMonthlyPace(reference: Date) -> Double {
        var totals: [Double] = []
        for offset in 0..<3 {
            guard let d = calendar.date(byAdding: .month, value: -offset, to: reference),
                  let interval = calendar.dateInterval(of: .month, for: d) else { continue }
            totals.append(SpendingAnalysisCalculator.totalSpent(rows: confirmedRows, in: interval))
        }
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }
}

// MARK: - Models

private struct DonutSlice: Identifiable {
    var id: Category { category }
    let category: Category
    let amount: Double
    var selectionKey: String { category.rawValue }
}

private struct WeekSpendSummary: Identifiable {
    var id: Int { index }
    let index: Int
    let total: Double
    let topCategory: Category?
}

private struct SubscriptionAuditRow: Identifiable {
    let id: String
    let name: String
    let monthlyCostEstimate: Double
    let monthsDetected: Int
}

// MARK: - Subscription detection

private enum SubscriptionAuditBuilder {
    static func build(from transactions: [Transaction], calendar: Calendar) -> [SubscriptionAuditRow] {
        let subs = transactions.filter(\.isConfirmed).filter { $0.category == .subscriptions }
        var byName: [String: [Transaction]] = [:]
        for tx in subs {
            let key = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            byName[key, default: []].append(tx)
        }
        return byName.map { name, txs in
            var monthKeys = Set<String>()
            for t in txs {
                let c = calendar.dateComponents([.year, .month], from: t.date)
                if let y = c.year, let m = c.month {
                    monthKeys.insert("\(y)-\(m)")
                }
            }
            let months = max(1, monthKeys.count)
            let total = txs.reduce(0) { $0 + $1.amount }
            let monthly = total / Double(months)
            return SubscriptionAuditRow(
                id: name,
                name: name,
                monthlyCostEstimate: monthly,
                monthsDetected: monthKeys.count
            )
        }
        .sorted { $0.monthlyCostEstimate > $1.monthlyCostEstimate }
    }
}

// MARK: - Calendar helpers

private enum InsightsCalendar {
    static func startOfMonth(for date: Date) -> Date {
        Calendar(identifier: .gregorian).date(from: Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)) ?? date
    }

    static func lastSixMonthStarts(reference: Date, calendar: Calendar) -> [Date] {
        (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: startOfMonth(for: reference))
        }.reversed()
    }
}

// MARK: - Preview

// Preview: DeveloperPreviewData.swift
