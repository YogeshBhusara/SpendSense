//
//  WidgetSnapshotStore.swift
//  SpendSense
//
//  Writes non-sensitive aggregates for a home-screen widget (month-to-date total,
//  daily nudge line). No merchant names. Enable the app group on the main app and
//  widget targets when you add a Widget Extension.
//

import Foundation

enum WidgetSnapshotStore {
    /// Set to your App Group when the widget target exists, e.g. "group.com.yogeshbhusara.SpendSense"
    static let appGroupIdentifier: String? = nil

    private static let mtdKey = "widgetMonthToDateTotal"
    private static let nudgeKey = "widgetDailyNudgeLine"
    private static let currencyCodeKey = "widgetCurrencyCode"

    static func update(monthToDateTotal: Double, dailyNudge: String, currencyCode: String = "INR") {
        guard let id = appGroupIdentifier,
              let defaults = UserDefaults(suiteName: id) else { return }
        defaults.set(monthToDateTotal, forKey: mtdKey)
        defaults.set(dailyNudge, forKey: nudgeKey)
        defaults.set(currencyCode, forKey: currencyCodeKey)
    }
}
