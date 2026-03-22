//
//  DashboardView.swift
//  SpendSense
//

import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(OnboardingStorageKey.softMonthlyGoal) private var softMonthlyGoal = 25_000.0
    @AppStorage(OnboardingStorageKey.userFirstName) private var userFirstName = ""
    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"

    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedChartDate: Date?
    @State private var sheetDayItem: DaySheetItem?
    @State private var showConfirmationTray = false
    @State private var showManualEntry = false
    @State private var lastUnconfirmedCount = 0
    @State private var didAutoPresentConfirmationTray = false
    @State private var dashboardStaggered = false

    @Query(
        filter: #Predicate<Transaction> { $0.isConfirmed == false },
        sort: [SortDescriptor(\.date, order: .reverse)]
    )
    private var unconfirmedTransactions: [Transaction]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dashboardHeader
                        .modifier(DashboardStaggerModifier(index: 0, appeared: dashboardStaggered))

                    if viewModel.allTransactions.isEmpty, !viewModel.isLoading {
                        DashboardTransactionsEmptyState()
                            .modifier(DashboardStaggerModifier(index: 1, appeared: dashboardStaggered))
                    } else {
                        monthlyPulseCard
                            .modifier(DashboardStaggerModifier(index: 1, appeared: dashboardStaggered))
                        rhythmSection
                            .modifier(DashboardStaggerModifier(index: 2, appeared: dashboardStaggered))
                        categoryChipsSection
                            .modifier(DashboardStaggerModifier(index: 3, appeared: dashboardStaggered))
                        recentSection
                            .modifier(DashboardStaggerModifier(index: 4, appeared: dashboardStaggered))
                        insightsSection
                            .modifier(DashboardStaggerModifier(index: 5, appeared: dashboardStaggered))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(SpendSensePalette.groupedBackground(for: colorScheme))
            .onAppear {
                dashboardStaggered = true
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !unconfirmedTransactions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showConfirmationTray = true
                        } label: {
                            Label("Review", systemImage: "tray.full")
                        }
                        .badge(unconfirmedTransactions.count)
                    }
                }
            }
            .refreshable {
                await viewModel.load(modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
            }
            .task {
                await viewModel.load(modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
            }
            .onChange(of: softMonthlyGoal) { _, _ in
                Task {
                    await viewModel.load(modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
                }
            }
            .onChange(of: selectedChartDate) { _, newValue in
                if let newValue {
                    let start = Calendar.current.startOfDay(for: newValue)
                    sheetDayItem = DaySheetItem(dayStart: start)
                }
            }
            .sheet(item: $sheetDayItem) { item in
                DayTransactionsSheet(
                    day: item.dayStart,
                    transactions: viewModel.transactions(on: item.dayStart),
                    currencyCode: currencyCode,
                    onConfirm: { tx in
                        Task {
                            await viewModel.confirm(tx, modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
                        }
                    }
                )
            }
            .onChange(of: sheetDayItem) { _, new in
                if new == nil {
                    selectedChartDate = nil
                    Task {
                        await viewModel.load(modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
                    }
                }
            }
            .navigationDestination(for: Category.self) { category in
                CategoryDetailView(category: category)
            }
            .onAppear {
                let count = unconfirmedTransactions.count
                lastUnconfirmedCount = count
                if count > 0, !didAutoPresentConfirmationTray {
                    showConfirmationTray = true
                    didAutoPresentConfirmationTray = true
                }
            }
            .onChange(of: unconfirmedTransactions.count) { _, newValue in
                let prev = lastUnconfirmedCount
                if newValue == 0 {
                    showConfirmationTray = false
                    didAutoPresentConfirmationTray = false
                } else if newValue > prev {
                    showConfirmationTray = true
                }
                lastUnconfirmedCount = newValue
            }
            .sheet(isPresented: $showConfirmationTray) {
                TransactionConfirmationTrayContent()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showManualEntry) {
                ManualTransactionEntrySheet()
                    .presentationDetents([.large])
            }
        }

            Button {
                showManualEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        SpendSensePalette.softCoral,
                                        SpendSensePalette.amber.opacity(0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                    )
            }
            .accessibilityLabel("Add transaction")
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingLine)
                    .font(SpendSenseTypography.text(.title2, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .placeholderSkeleton(viewModel.isLoading)
                Text(viewModel.dailyNudge)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .placeholderSkeleton(viewModel.isLoading)
            }
            avatarView
        }
        .padding(.top, 8)
    }

    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let salute: String
        if hour < 12 { salute = "Good morning" }
        else if hour < 17 { salute = "Good afternoon" }
        else { salute = "Good evening" }
        let trimmed = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "there" : trimmed
        return "\(salute), \(name)"
    }

    private var avatarView: some View {
        let initials = avatarInitials(from: userFirstName)
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            SpendSensePalette.warmTeal.opacity(0.92),
                            SpendSensePalette.warmTeal.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Profile \(initials)")
    }

    private func avatarInitials(from name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        if let first = parts.first, first.count >= 2 {
            return String(first.prefix(2)).uppercased()
        }
        if let first = parts.first, let c = first.first {
            return String(c).uppercased()
        }
        return "SS"
    }

    // MARK: - Monthly pulse

    private var monthlyPulseCard: some View {
        MonthlyPulseCardView(
            isLoading: viewModel.isLoading,
            mood: viewModel.spendMood,
            monthlyTotal: viewModel.monthlyTotal,
            softGoal: viewModel.softGoal,
            ringProgress: viewModel.ringProgress,
            daysLeft: viewModel.daysLeftInMonth,
            monthName: viewModel.currentMonthLabel,
            averagePerDay: viewModel.averagePerDayThisMonth,
            currencyCode: currencyCode
        )
    }

    // MARK: - Rhythm chart

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your spending rhythm this month")
                .font(.headline)
                .placeholderSkeleton(viewModel.isLoading)

            Chart(viewModel.rhythmDays) { point in
                BarMark(
                    x: .value("Day", point.dayStart, unit: .day),
                    y: .value("Spend", point.amount)
                )
                .foregroundStyle(rhythmBarColor(amount: point.amount))
                .cornerRadius(4)
            }
            .chartXSelection(value: $selectedChartDate)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(shortINR(v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) {
                    AxisValueLabel(format: .dateTime.day(.defaultDigits))
                }
            }
            .frame(height: 180)
            .padding(SpendSenseLayout.unit + 4)
            .spendSenseCardSurface(shadow: true)
            .placeholderSkeleton(viewModel.isLoading)
        }
    }

    private func rhythmBarColor(amount: Double) -> Color {
        let maxA = max(viewModel.maxRhythmAmount, 1)
        let t = min(1, amount / maxA)
        let r = (45 + t * 206) / 255
        let g = (212 - t * 21) / 255
        let b = (191 - t * 155) / 255
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Categories

    private var categoryChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top categories")
                .font(.headline)
                .placeholderSkeleton(viewModel.isLoading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.categoryChips) { chip in
                        NavigationLink(value: chip.category) {
                            CategoryChipView(
                                emoji: chip.category.emoji,
                                name: chip.category.displayName,
                                amount: chip.amount,
                                currencyCode: currencyCode
                            )
                        }
                        .buttonStyle(CategoryChipSpringButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .placeholderSkeleton(viewModel.isLoading)
        }
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    AllTransactionsView(transactions: viewModel.allTransactions, currencyCode: currencyCode)
                }
                .font(.subheadline.weight(.medium))
            }
            .placeholderSkeleton(viewModel.isLoading)

            VStack(spacing: 0) {
                ForEach(viewModel.recentTransactions, id: \.id) { tx in
                    RecentTransactionRow(transaction: tx, currencyCode: currencyCode) {
                        Task {
                            await viewModel.confirm(tx, modelContext: modelContext, softMonthlyGoal: softMonthlyGoal)
                        }
                    }
                    if tx.id != viewModel.recentTransactions.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .padding(SpendSenseLayout.unit + 4)
            .spendSenseCardSurface(shadow: true)
            .placeholderSkeleton(viewModel.isLoading)
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .placeholderSkeleton(viewModel.isLoading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(viewModel.insights.enumerated()), id: \.element.id) { index, insight in
                        SwipeDismissInsightCard(
                            insight: insight,
                            appearDelay: Double(index) * 0.06
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.dismissInsight(id: insight.id)
                            }
                        }
                        .id(insight.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .placeholderSkeleton(viewModel.isLoading)
        }
    }

    private func shortINR(_ value: Double) -> String {
        SpendSenseCurrency.format(amount: value, currencyCode: currencyCode)
    }
}

// MARK: - Staggered section entrance

private struct DashboardStaggerModifier: ViewModifier {
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 22)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.84)
                    .delay(Double(index) * 0.065),
                value: appeared
            )
    }
}

// MARK: - Category chip press

private struct CategoryChipSpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - Day sheet item

private struct DaySheetItem: Identifiable, Equatable {
    let dayStart: Date
    var id: Date { dayStart }
}

// MARK: - Monthly pulse card

private struct MonthlyPulseCardView: View {
    let isLoading: Bool
    let mood: SpendMood
    let monthlyTotal: Double
    let softGoal: Double
    let ringProgress: Double
    let daysLeft: Int
    let monthName: String
    let averagePerDay: Double
    let currencyCode: String

    @State private var displayedTotal: Double = 0

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SpendSenseLayout.heroCornerRadius, style: .continuous)
                .fill(moodGradient)

            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This month")
                        .font(SpendSenseTypography.text(.subheadline, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(currencyFormatter.string(from: NSNumber(value: displayedTotal)) ?? "—")
                        .font(SpendSenseTypography.money(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("\(daysLeft) days left in \(monthName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("avg \(currencyFormatter.string(from: NSNumber(value: averagePerDay)) ?? "—")/day")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 6)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: min(ringProgress, 1.08))
                        .stroke(
                            .white.opacity(0.92),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("goal")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(currencyFormatter.string(from: NSNumber(value: softGoal)) ?? "—")
                            .font(SpendSenseTypography.money(.caption, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 72)
                }
            }
            .padding(SpendSenseLayout.s24 - 2)
        }
        .frame(minHeight: 168)
        .spendSenseCardShadow()
        .placeholderSkeleton(isLoading)
        .task(id: isLoading) {
            if isLoading {
                displayedTotal = 0
            } else {
                displayedTotal = 0
                await Task.yield()
                withAnimation(.easeOut(duration: 0.95)) {
                    displayedTotal = monthlyTotal
                }
            }
        }
        .onChange(of: monthlyTotal) { _, new in
            guard !isLoading else { return }
            withAnimation(.easeOut(duration: 0.55)) {
                displayedTotal = new
            }
        }
    }

    private var moodGradient: LinearGradient {
        switch mood {
        case .underBudget:
            return LinearGradient(
                colors: [
                    SpendSensePalette.warmTeal.opacity(0.88),
                    SpendSensePalette.sage.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .onTrack:
            return LinearGradient(
                colors: [
                    SpendSensePalette.amber.opacity(0.92),
                    SpendSensePalette.amber.opacity(0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .overSoftGoal:
            return LinearGradient(
                colors: [
                    SpendSensePalette.softCoral.opacity(0.95),
                    SpendSensePalette.amber.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Category chip

private struct CategoryChipView: View {
    @Environment(\.colorScheme) private var colorScheme

    let emoji: String
    let name: String
    let amount: Double
    let currencyCode: String

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }

    var body: some View {
        HStack(spacing: SpendSenseLayout.unit) {
            Text(emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(SpendSenseTypography.text(.subheadline, weight: .semibold))
                Text(currencyFormatter.string(from: NSNumber(value: amount)) ?? "—")
                    .font(SpendSenseTypography.money(.caption, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, SpendSenseLayout.s16 - 2)
        .padding(.vertical, SpendSenseLayout.unit + 2)
        .background(
            RoundedRectangle(cornerRadius: SpendSenseLayout.chipCornerRadius, style: .continuous)
                .fill(SpendSensePalette.cardSurface(for: colorScheme))
        )
    }
}

// MARK: - Recent row

private struct RecentTransactionRow: View {
    let transaction: Transaction
    let currencyCode: String
    let onConfirm: () -> Void

    @AppStorage(SettingsStorageKey.showEmotionalTags) private var showEmotionalTags = true
    @State private var pulseOpacity: Double = 0.2

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }

    var body: some View {
        Button(action: {
            if !transaction.isConfirmed {
                onConfirm()
            }
        }) {
            HStack(alignment: .center, spacing: 12) {
                Text(transaction.category.emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchant)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !transaction.isConfirmed {
                            Text("Tap to confirm")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text(currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? "—")
                    .font(SpendSenseTypography.money(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if showEmotionalTags {
                    EmotionalTagDot(tag: transaction.emotionalTag)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay {
            if !transaction.isConfirmed {
                RoundedRectangle(cornerRadius: SpendSenseLayout.chipCornerRadius, style: .continuous)
                    .stroke(SpendSensePalette.warmTeal.opacity(pulseOpacity), lineWidth: 1.5)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulseOpacity
                    )
            }
        }
        .onAppear {
            if !transaction.isConfirmed {
                pulseOpacity = 0.55
            }
        }
    }
}

// MARK: - Emotional tag dot

private struct EmotionalTagDot: View {
    let tag: EmotionalTag?

    var body: some View {
        Circle()
            .fill(tagColor)
            .frame(width: 8, height: 8)
            .accessibilityLabel(tag.map { $0.label } ?? "No tag")
    }

    private var tagColor: Color {
        guard let tag else { return Color.secondary.opacity(0.25) }
        return Color(hex: tag.color) ?? SpendSensePalette.warmTeal
    }
}

// MARK: - Swipe insight card

private struct SwipeDismissInsightCard: View {
    let insight: InsightCardData
    let appearDelay: Double
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGFloat = 0
    @State private var entranceReady = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.title)
                .font(.subheadline.weight(.semibold))
            Text(insight.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpendSenseLayout.s16 - 2)
        .frame(width: 268, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SpendSenseLayout.cardCornerRadius, style: .continuous)
                .fill(SpendSensePalette.cardSurface(for: colorScheme))
        )
        .spendSenseCardShadow()
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.left")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(8)
        }
        .offset(x: dragOffset)
        .opacity(entranceReady ? 1 : 0)
        .scaleEffect(entranceReady ? 1 : 0.9)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = min(0, value.translation.width)
                }
                .onEnded { value in
                    if value.translation.width < -72 {
                        onDismiss()
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
        .accessibilityHint("Swipe left to dismiss")
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82).delay(appearDelay)) {
                entranceReady = true
            }
        }
    }

}

// MARK: - Day transactions sheet

private struct DayTransactionsSheet: View {
    let day: Date
    let transactions: [Transaction]
    let currencyCode: String
    let onConfirm: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }

    var body: some View {
        NavigationStack {
            List(transactions, id: \.id) { tx in
                Button {
                    if !tx.isConfirmed {
                        onConfirm(tx)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tx.merchant)
                                .font(.headline)
                            Text(tx.category.emoji + " · " + (tx.isConfirmed ? "Confirmed" : "Tap to confirm"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(currencyFormatter.string(from: NSNumber(value: tx.amount)) ?? "—")
                            .font(SpendSenseTypography.money(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(day.formatted(date: .long, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview (see DeveloperPreviewData.swift)
