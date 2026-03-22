//
//  LocalNotificationScheduler.swift
//  SpendSense
//
//  Local notifications only — no remote push, no server.
//

import Foundation
import UserNotifications

@MainActor
enum LocalNotificationScheduler {
    private static let weeklyId = "com.spendsense.local.weeklyInsight"
    private static let dailyId = "com.spendsense.local.dailyNudge"

    static func requestAuthorizationIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func refreshWeeklyInsight(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyId])
        guard enabled else { return }

        var components = DateComponents()
        components.weekday = 1
        components.hour = 10
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Weekly insight"
        content.body = "A gentle SpendSense summary is ready — open when you want a soft look back."
        content.sound = .default

        let request = UNNotificationRequest(identifier: weeklyId, content: content, trigger: trigger)
        center.add(request)
    }

    static func refreshDailyNudge(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyId])
        guard enabled else { return }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "SpendSense"
        content.body = "Good morning — here’s a tiny nudge for your spending story, only if you want it."
        content.sound = .default

        let request = UNNotificationRequest(identifier: dailyId, content: content, trigger: trigger)
        center.add(request)
    }

    /// Clears SpendSense local notification requests (used on “Delete all data”).
    static func removeAllSpendSenseRequests() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyId, dailyId])
    }
}
