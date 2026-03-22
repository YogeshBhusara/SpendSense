//
//  CategoryDetailView.swift
//  SpendSense
//

import Charts
import SwiftData
import SwiftUI

// MARK: - Scroll offset (parallax)

private struct CategoryDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - CategoryDetailView

struct CategoryDetailView: View {
    let category: Category

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(SettingsStorageKey.showEmotionalTags) private var showEmotionalTags = true
    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"
    @Query private var transactions: [Transaction]

    @State private var scrollMinY: CGFloat = 0
    @State private var selectedHistoryMonth: Date?
    @State private var monthPopoverItem: MonthPopoverItem?
    @State private var noteTarget: Transaction?
    @State private var isNoteSheetPresented = false
    @State private var transactionPendingDelete: Transaction?

    private let calendar = Calendar(identifier: .gregorian)

    init(category: Category) {
        self.category = category
        let cat = category
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.category == cat },
            sort: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: CategoryDetailScrollOffsetKey.self,
                                value: proxy.frame(in: .named("categoryScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    parallaxHeader

                    VStack(alignment: .leading, spacing: 28) {
                        merchantBreakdownSection
                        transactionListSection
                        categoryInsightSection
                        monthlyHistorySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            .coordinateSpace(name: "categoryScroll")
            .onPreferenceChange(CategoryDetailScrollOffsetKey.self) { scrollMinY = $0 }
            .onChange(of: selectedHistoryMonth) { _, new in
                syncMonthPopover(with: new)
            }
            .onChange(of: monthPopoverItem) { _, new in
                if new == nil {
                    selectedHistoryMonth = nil
                }
            }
        }
        .background(SpendSensePalette.groupedBackground(for: colorScheme))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                    }
                    .foregroundStyle(categorySwiftUIColor)
                }
                .accessibilityLabel("Go back")
            }
        }
        .sheet(isPresented: $isNoteSheetPresented, onDismiss: { noteTarget = nil }) {
            if let tx = noteTarget {
                NoteEditorSheet(
                    merchant: tx.merchant,
                    initialNote: tx.note ?? "",
                    onSave: { text in
                        tx.note = text.isEmpty ? nil : text
                        try? modelContext.save()
                    }
                )
            }
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: Binding(
                get: { transactionPendingDelete != nil },
                set: { if !$0 { transactionPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tx = transactionPendingDelete {
                    modelContext.delete(tx)
                    try? modelContext.save()
                }
                transactionPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                transactionPendingDelete = nil
            }
        } message: {
            Text("This can’t be undone.")
        }
    }

    // MARK: - Header (parallax)

    private var parallaxHeader: some View {
        let stretch = max(0, scrollMinY)
        let parallaxShift = stretch * 0.35 + min(0, scrollMinY) * 0.15

        return ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            categorySwiftUIColor.opacity(0.45),
                            categorySwiftUIColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200 + stretch)
                .offset(y: -stretch)

            VStack(alignment: .leading, spacing: 12) {
                Text(category.emoji)
                    .font(.system(size: 56))
                    .scaleEffect(1 + min(stretch, 80) / 400, anchor: .bottomLeading)
                    .offset(y: parallaxShift * 0.4)
                    .accessibilityHidden(true)

                Text(category.displayName)
                    .font(SpendSenseTypography.text(.largeTitle, weight: .semibold))
                    .offset(y: parallaxShift * 0.25)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(currencyFormatter.string(from: NSNumber(value: thisMonthTotal)) ?? "—")
                        .font(SpendSenseTypography.money(size: 36, weight: .bold))
                        .monospacedDigit()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("this month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("was \(currencyFormatter.string(from: NSNumber(value: lastMonthTotal)) ?? "—")")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                .offset(y: parallaxShift * 0.15)

                trendRow
                    .padding(.top, 4)
                    .offset(y: parallaxShift * 0.1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .frame(height: 200)
        .clipped()
    }

    private var trendRow: some View {
        HStack(spacing: 6) {
            if lastMonthTotal > 0 || thisMonthTotal > 0 {
                Image(systemName: trendPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trendPercent >= 0
                        ? SpendSenseSemanticColor.elevatedSpendWarm.opacity(0.92)
                        : SpendSenseSemanticColor.onTrack.opacity(0.92))
                Text("\(abs(trendPercent), format: .number.precision(.fractionLength(0)))% vs last month")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Not enough history yet to compare months")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Merchant breakdown

    private var merchantBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top merchants")
                .font(.headline)

            if topMerchantsThisMonth.isEmpty {
                Text("No spends in this category this month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(topMerchantsThisMonth) { row in
                    BarMark(
                        x: .value("Amount", row.total),
                        y: .value("Merchant", row.merchant)
                    )
                    .foregroundStyle(categorySwiftUIColor.opacity(row.opacity))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(SpendSenseCurrency.format(amount: v, currencyCode: currencyCode))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(max(120, topMerchantsThisMonth.count * 36)))
                .padding(SpendSenseLayout.unit + 4)
                .spendSenseCardSurface(shadow: true)
            }
        }
    }

    // MARK: - Transactions (grouped by week)

    private var transactionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            if transactions.isEmpty {
                Text("Nothing here yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedByWeekKeys, id: \.self) { weekStart in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(weekSectionTitle(weekStart))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(groupedByWeek[weekStart] ?? [], id: \.id) { tx in
                            transactionRow(tx)
                        }
                    }
                }
            }
        }
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currencyFormatter.string(from: NSNumber(value: tx.amount)) ?? "—")
                    .font(SpendSenseTypography.money(.subheadline, weight: .semibold))
                    .monospacedDigit()
                Text(tx.merchant)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if showEmotionalTags {
                emotionalTagBadge(tx.emotionalTag)
            }
        }
        .padding(SpendSenseLayout.s16 - 2)
        .spendSenseCardSurface(shadow: false)
        .contextMenu {
            Button("Mark as Essential") {
                tx.emotionalTag = .essential
                try? modelContext.save()
            }
            Button("Mark as Impulse") {
                tx.emotionalTag = .impulse
                try? modelContext.save()
            }
            Button("Add note") {
                noteTarget = tx
                isNoteSheetPresented = true
            }
            Button("Delete", role: .destructive) {
                transactionPendingDelete = tx
            }
        }
    }

    @ViewBuilder
    private func emotionalTagBadge(_ tag: EmotionalTag?) -> some View {
        if let tag {
            Text(tag.label)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tagSwiftUIColor(tag).opacity(0.18), in: Capsule())
                .foregroundStyle(tagSwiftUIColor(tag))
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Insight

    private var categoryInsightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A little context")
                .font(.headline)

            Text(CategoryInsightCopy.insight(for: category, transactions: transactions, calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    categorySwiftUIColor.opacity(0.14),
                                    categorySwiftUIColor.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }

    // MARK: - Monthly history

    private var monthlyHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 6 months")
                .font(.headline)

            if lastSixMonthPoints.allSatisfy({ $0.total == 0 }) {
                Text("Spend in this category will show up here over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(lastSixMonthPoints) { point in
                    LineMark(
                        x: .value("Month", point.monthStart, unit: .month),
                        y: .value("Spend", point.total)
                    )
                    .foregroundStyle(categorySwiftUIColor)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Month", point.monthStart, unit: .month),
                        y: .value("Spend", point.total)
                    )
                    .foregroundStyle(categorySwiftUIColor)
                    .symbolSize(60)
                }
                .chartXSelection(value: $selectedHistoryMonth)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(SpendSenseCurrency.format(amount: v, currencyCode: currencyCode))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 200)
                .padding(SpendSenseLayout.unit + 4)
                .spendSenseCardSurface(shadow: true)
                .popover(item: $monthPopoverItem) { item in
                    monthPopoverContent(monthStart: item.monthStart)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    private func syncMonthPopover(with selected: Date?) {
        guard let selected else {
            monthPopoverItem = nil
            return
        }
        let start = calendar.dateInterval(of: .month, for: selected)?.start
            ?? calendar.startOfDay(for: selected)
        monthPopoverItem = MonthPopoverItem(monthStart: start)
    }

    private func monthPopoverContent(monthStart: Date) -> some View {
        let total = totalInCategory(forMonthStarting: monthStart)
        let count = transactionCountInCategory(forMonthStarting: monthStart)
        let label = monthStart.formatted(.dateTime.month(.wide).year())

        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            Text(currencyFormatter.string(from: NSNumber(value: total)) ?? "—")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text("\(count) transactions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 200)
    }

    // MARK: - Data

    private var thisMonthTotal: Double {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        return transactions.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private var lastMonthTotal: Double {
        guard let ref = calendar.date(byAdding: .month, value: -1, to: Date()),
              let interval = calendar.dateInterval(of: .month, for: ref) else { return 0 }
        return transactions.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    /// Percent change vs last month (positive = spent more this month).
    private var trendPercent: Double {
        guard lastMonthTotal > 0 else {
            return thisMonthTotal > 0 ? 100 : 0
        }
        return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
    }

    private struct MerchantRow: Identifiable {
        var id: String { merchant }
        let merchant: String
        let total: Double
        let opacity: Double
    }

    private var topMerchantsThisMonth: [MerchantRow] {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        var totals: [String: Double] = [:]
        for tx in transactions where interval.contains(tx.date) {
            let m = tx.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !m.isEmpty else { continue }
            totals[m, default: 0] += tx.amount
        }
        let sorted = totals.sorted { $0.value > $1.value }.prefix(5)
        let maxT = sorted.map(\.value).max() ?? 1
        return sorted.enumerated().map { index, pair in
            let intensity = maxT > 0 ? pair.value / maxT : 0
            let opacity = 0.42 + intensity * 0.55
            return MerchantRow(merchant: pair.key, total: pair.value, opacity: opacity)
        }
    }

    private struct MonthPoint: Identifiable {
        var id: Date { monthStart }
        let monthStart: Date
        let total: Double
    }

    private var lastSixMonthPoints: [MonthPoint] {
        var points: [MonthPoint] = []
        for offset in (0..<6).reversed() {
            guard let anchor = calendar.date(byAdding: .month, value: -offset, to: Date()),
                  let interval = calendar.dateInterval(of: .month, for: anchor) else { continue }
            let total = transactions.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
            points.append(MonthPoint(monthStart: interval.start, total: total))
        }
        return points
    }

    private func totalInCategory(forMonthStarting monthStart: Date) -> Double {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else { return 0 }
        return transactions.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private func transactionCountInCategory(forMonthStarting monthStart: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else { return 0 }
        return transactions.filter { interval.contains($0.date) }.count
    }

    private var groupedByWeek: [Date: [Transaction]] {
        Dictionary(grouping: transactions) { tx in
            guard let w = calendar.dateInterval(of: .weekOfYear, for: tx.date) else { return tx.date }
            return w.start
        }
    }

    private var groupedByWeekKeys: [Date] {
        groupedByWeek.keys.sorted(by: >)
    }

    private func weekSectionTitle(_ weekStart: Date) -> String {
        if calendar.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear) {
            return "This week"
        }
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let f = DateIntervalFormatter()
        f.dateStyle = .medium
        return f.string(from: weekStart, to: end)
    }

    private var categorySwiftUIColor: Color {
        Color(hex: category.color) ?? .accentColor
    }

    private func tagSwiftUIColor(_ tag: EmotionalTag) -> Color {
        Color(hex: tag.color) ?? .secondary
    }

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }
}

// MARK: - Month popover binding item

private struct MonthPopoverItem: Identifiable, Equatable {
    let monthStart: Date
    var id: Date { monthStart }
}

// MARK: - Note sheet

private struct NoteEditorSheet: View {
    let merchant: String
    let initialNote: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(merchant: String, initialNote: String, onSave: @escaping (String) -> Void) {
        self.merchant = merchant
        self.initialNote = initialNote
        self.onSave = onSave
        _text = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(merchant)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Note", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }
            .padding()
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category insight copy (local, warm)

private enum CategoryInsightCopy {
    static func insight(for category: Category, transactions: [Transaction], calendar: Calendar) -> String {
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else {
            return "We’ll share gentle observations here as your history grows."
        }
        let monthTx = transactions.filter { monthInterval.contains($0.date) }
        let count = monthTx.count
        let total = monthTx.reduce(0) { $0 + $1.amount }
        let dayOfMonth = max(1, calendar.component(.day, from: Date()))
        let spacing = count > 0 ? max(1, Int(round(Double(dayOfMonth) / Double(count)))) : 0

        switch category {
        case .food:
            if count == 0 {
                return "No food spends logged this month yet — when you do, we’ll paint a cozy picture here 🍽️"
            }
            return "You’ve logged \(count) food moments this month — roughly every \(spacing) days or so, give or take ☕"
        case .transport:
            if count == 0 {
                return "Transport will show its rhythm here once a few trips land in this category."
            }
            return "\(count) transport taps this month — however you moved around, you’re keeping the thread visible 🚗"
        case .shopping:
            if count == 0 {
                return "Shopping in this space is quiet so far — totally fine if you’re in a low-buy season."
            }
            return "\(count) shopping moments this month — small picks add up to a story; yours is just unfolding 🛍️"
        case .entertainment:
            return count == 0
                ? "Room for fun when you want it — we’ll note the pattern gently when it shows up."
                : "\(count) entertainment spends — however you unwind, it’s yours to enjoy without a scorecard 🎬"
        case .bills:
            return "Bills tend to be steady companions — \(count) entries this month keeping the lights on, literally or figuratively 📄"
        case .health:
            return count == 0
                ? "Health spending is personal — we’ll reflect it softly when there’s something to show."
                : "\(count) health-related entries — taking care of you counts, quietly ❤️‍🩹"
        case .travel:
            return count == 0
                ? "No travel spends this month — wanderlust can wait, or show up all at once ✈️"
                : "\(count) travel touches this month — however far you went, it’s noted without drama ✈️"
        case .subscriptions:
            return count == 0
                ? "Subscriptions are easy to forget — when they appear, we’ll line them up kindly 📱"
                : "About \(count) subscription-style entries — worth a calm glance when you’re curious 📱"
        case .other:
            return count == 0
                ? "This bucket is wide open — we’ll summarize whatever lands here, gently 📦"
                : "\(count) entries in “other” — life doesn’t always fit labels, and that’s okay 📦"
        }
    }
}
