//
//  SpendSenseWidgetBundle.swift
//  SpendSenseWidget
//
//  Add a Widget Extension target in Xcode, set the same App Group as the main app,
//  set `WidgetSnapshotStore.appGroupIdentifier` in the app, and embed this extension.
//  The widget shows only month-to-date total and a short nudge line — no merchants.
//

import SwiftUI
import WidgetKit

@main
struct SpendSenseWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendSenseTotalsWidget()
    }
}

private enum WidgetSharedKeys {
    static let suiteName = "group.com.yogeshbhusara.SpendSense"
    static let mtd = "widgetMonthToDateTotal"
    static let nudge = "widgetDailyNudgeLine"
    static let currency = "widgetCurrencyCode"
}

struct SpendSenseTotalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.spendsense.widget.totals", provider: TotalsProvider()) { entry in
            TotalsWidgetView(entry: entry)
        }
        .configurationDisplayName("SpendSense")
        .description("Month-to-date total and a gentle nudge. No transaction details.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TotalsEntry: TimelineEntry {
    let date: Date
    let monthToDate: Double
    let nudge: String
    let currencyCode: String
}

private struct TotalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TotalsEntry {
        TotalsEntry(date: .now, monthToDate: 12_400, nudge: "Hope your day starts kind.", currencyCode: "INR")
    }

    func getSnapshot(in context: Context, completion: @escaping (TotalsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TotalsEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now.addingTimeInterval(14_400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> TotalsEntry {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.suiteName) else {
            return TotalsEntry(date: .now, monthToDate: 0, nudge: "Open SpendSense to refresh.", currencyCode: "INR")
        }
        let total = defaults.double(forKey: WidgetSharedKeys.mtd)
        let nudge = defaults.string(forKey: WidgetSharedKeys.nudge) ?? "A soft check-in when you’re ready."
        let code = defaults.string(forKey: WidgetSharedKeys.currency) ?? "INR"
        return TotalsEntry(date: .now, monthToDate: total, nudge: nudge, currencyCode: code)
    }
}

private struct TotalsWidgetView: View {
    let entry: TotalsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This month")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(formattedTotal)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(entry.nudge)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var formattedTotal: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = entry.currencyCode
        f.locale = Locale(identifier: "en_IN")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: entry.monthToDate)) ?? "—"
    }
}
