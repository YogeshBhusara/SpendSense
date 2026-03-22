//
//  DeveloperPreviewData.swift
//  SpendSense
//
//  Sample transactions/insights for previews (DEBUG) and unit tests (`makeSampleTransactions()`).
//

import Foundation
import SwiftData
import SwiftUI

enum DeveloperPreviewData {

    // MARK: - Sample insights (5)

    static func makeSampleInsights() -> [SpendingInsight] {
        [
            SpendingInsight(
                type: .weeklyHigh,
                title: "A theme showed up",
                body: "Looks like this week was a food-heavy one 🍽️ — mostly just a pattern, not a verdict.",
                createdAt: Date().addingTimeInterval(-86_400 * 2),
                isRead: false
            ),
            SpendingInsight(
                type: .unusualSpike,
                title: "One purchase stood out",
                body: "That ₹8,500 at Amazon stands out this month — treat-yourself moment? 🛍️",
                createdAt: Date().addingTimeInterval(-86_400 * 4),
                isRead: true
            ),
            SpendingInsight(
                type: .positiveReinforcement,
                title: "Nice little streak",
                body: "3 weeks in a row you've kept food spend under ₹2,000 🎉",
                createdAt: Date().addingTimeInterval(-86_400 * 6),
                isRead: false
            ),
            SpendingInsight(
                type: .quietWeek,
                title: "Soft week overall",
                body: "Compared with your recent weeks, this one ran a little lighter — however that lands for you.",
                createdAt: Date().addingTimeInterval(-86_400 * 8),
                isRead: false
            ),
            SpendingInsight(
                type: .streakBreak,
                title: "A little more dining energy",
                body: "Food spend edged up compared with your last few weeks — variety counts too.",
                createdAt: Date().addingTimeInterval(-86_400 * 10),
                isRead: false
            )
        ]
    }

    // MARK: - Sample transactions (60)

    private static let merchantLineup: [(merchant: String, category: Category)] = [
        ("Swiggy", .food),
        ("Zomato", .food),
        ("BigBasket", .food),
        ("DMart", .food),
        ("Ola", .transport),
        ("Uber", .transport),
        ("Amazon", .shopping),
        ("Flipkart", .shopping),
        ("Croma", .shopping),
        ("Netflix", .subscriptions),
        ("Spotify", .subscriptions),
        ("BESCOM", .bills),
        ("Airtel", .bills),
        ("BookMyShow", .entertainment),
        ("PVR", .entertainment),
        ("MakeMyTrip", .travel),
        ("Goibibo", .travel),
        ("Apollo Pharmacy", .health),
        ("1mg", .health),
        ("Local vendor", .other)
    ]

    private static let amountPalette: [Double] = [
        49, 65, 79, 89, 99, 119, 149, 179, 199, 249, 299, 349, 399, 449, 499,
        549, 599, 649, 699, 749, 799, 899, 999, 1_199, 1_299, 1_499, 1_799, 1_999,
        2_199, 2_499, 2_799, 2_999, 3_299, 3_499, 3_799, 4_199, 4_850, 5_200, 6_100,
        7_250, 8_500
    ]

    /// 60 transactions over ~90 days: mixed tags, 8 unconfirmed, large rows for insight spikes.
    static func makeSampleTransactions() -> [Transaction] {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let tags: [EmotionalTag?] = [.essential, .treat, .impulse, .subscription, nil]
        let unconfirmed: Set<Int> = [0, 4, 9, 14, 21, 28, 35, 47]

        var result: [Transaction] = []
        result.reserveCapacity(60)

        for i in 0..<60 {
            let spec = merchantLineup[i % merchantLineup.count]
            let dayBack = (i * 41 + (i * i) % 17) % 88 + 1
            let date = calendar.date(byAdding: .day, value: -dayBack, to: today) ?? today

            var amount = amountPalette[i % amountPalette.count]
            if i == 6 { amount = 8_500 }
            if i == 17 { amount = 8_200 }
            if i == 29 { amount = 4_999 }
            if i == 41 { amount = 3_200 }

            let tag = tags[i % tags.count]
            let suffix = i >= 20 ? " #\(i / 20)" : ""
            let merchant = spec.merchant + suffix

            let sms = "INR \(String(format: "%.2f", amount)) debited to \(merchant.uppercased()) on \(date.formatted(date: .numeric, time: .omitted)). Avl Bal Rs.XX,XXX"

            result.append(
                Transaction(
                    amount: amount,
                    merchant: merchant,
                    rawMessageText: sms,
                    date: date,
                    category: spec.category,
                    isConfirmed: !unconfirmed.contains(i),
                    emotionalTag: tag,
                    note: (i % 11 == 0) ? "Sample note" : nil
                )
            )
        }
        return result
    }

    // MARK: - SwiftUI previews

    @MainActor
    static func makePreviewContainer() -> ModelContainer {
        #if DEBUG
        makePreviewContainerWithSamples()
        #else
        makeEmptyPreviewContainer()
        #endif
    }

    @MainActor
    private static func makeEmptyPreviewContainer() -> ModelContainer {
        let schema = Schema([Transaction.self, SpendingInsight.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Preview ModelContainer: \(error)")
        }
    }

    #if DEBUG

    @MainActor
    static func loadSampleData(into context: ModelContext) {
        do {
            let existingTx = try context.fetch(FetchDescriptor<Transaction>())
            existingTx.forEach { context.delete($0) }

            let existingIn = try context.fetch(FetchDescriptor<SpendingInsight>())
            existingIn.forEach { context.delete($0) }

            for tx in makeSampleTransactions() {
                context.insert(tx)
            }
            for insight in makeSampleInsights() {
                context.insert(insight)
            }
            try context.save()
        } catch {
            assertionFailure("loadSampleData: \(error)")
        }
    }

    @MainActor
    private static func makePreviewContainerWithSamples() -> ModelContainer {
        let schema = Schema([Transaction.self, SpendingInsight.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let ctx = container.mainContext
            for tx in makeSampleTransactions() {
                ctx.insert(tx)
            }
            for ins in makeSampleInsights() {
                ctx.insert(ins)
            }
            try ctx.save()
            return container
        } catch {
            fatalError("Preview ModelContainer: \(error)")
        }
    }

    #endif
}

#if DEBUG

#Preview("ContentView") {
    ContentView()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("Dashboard") {
    DashboardView()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("Insights") {
    InsightsView()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("Settings") {
    SettingsView()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("Category — Food") {
    NavigationStack {
        CategoryDetailView(category: .food)
    }
    .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("All transactions") {
    PreviewAllTransactionsHost()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

private struct PreviewAllTransactionsHost: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        NavigationStack {
            AllTransactionsView(transactions: transactions)
        }
    }
}

#Preview("Review tray") {
    Text("Sheet")
        .sheet(isPresented: .constant(true)) {
            TransactionConfirmationTrayContent()
                .modelContainer(DeveloperPreviewData.makePreviewContainer())
        }
}

#Preview("Manual entry") {
    ManualTransactionEntrySheet()
        .modelContainer(DeveloperPreviewData.makePreviewContainer())
}

#Preview("Onboarding") {
    OnboardingView()
}

#endif
