//
//  SettingsKeys.swift
//  SpendSense
//

import Foundation

/// UserDefaults / `@AppStorage` keys for Settings and nuclear reset.
enum SettingsStorageKey {
    static let currencyCode = "settingsCurrencyCode"

    /// `Date.timeIntervalSince1970` of last successful message parse / scan.
    static let lastMessageScan = "settingsLastMessageScan"

    static let appearanceTheme = "settingsAppearanceTheme"
    /// teal, coral, amber, sage (legacy "lavender" resolves to sage in `SpendSenseAccent`)
    static let accentColorName = "settingsAccentColorName"

    static let showEmotionalTags = "settingsShowEmotionalTags"

    static let weeklyInsightNotification = "settingsWeeklyInsightNotification"
    static let dailyNudgeNotification = "settingsDailyNudgeNotification"
    static let dailyNudgeHour = "settingsDailyNudgeHour"
    static let dailyNudgeMinute = "settingsDailyNudgeMinute"

    /// Keys to remove on “Delete all data” (includes onboarding + settings).
    static var allKeysForNuclearReset: [String] {
        [
            OnboardingStorageKey.completed,
            OnboardingStorageKey.softMonthlyGoal,
            OnboardingStorageKey.manualEntry,
            OnboardingStorageKey.userFirstName,
            currencyCode,
            lastMessageScan,
            appearanceTheme,
            accentColorName,
            showEmotionalTags,
            weeklyInsightNotification,
            dailyNudgeNotification,
            dailyNudgeHour,
            dailyNudgeMinute
        ]
    }
}
