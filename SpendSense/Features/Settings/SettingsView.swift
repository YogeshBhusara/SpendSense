//
//  SettingsView.swift
//  SpendSense
//

import MessageUI
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(OnboardingStorageKey.userFirstName) private var userFirstName = ""
    @AppStorage(OnboardingStorageKey.softMonthlyGoal) private var softMonthlyGoal = 25_000.0
    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"

    @AppStorage(SettingsStorageKey.weeklyInsightNotification) private var weeklyInsightNotification = false
    @AppStorage(SettingsStorageKey.dailyNudgeNotification) private var dailyNudgeNotification = false
    @AppStorage(SettingsStorageKey.dailyNudgeHour) private var dailyNudgeHour = 8
    @AppStorage(SettingsStorageKey.dailyNudgeMinute) private var dailyNudgeMinute = 0

    @AppStorage(SettingsStorageKey.appearanceTheme) private var appearanceTheme = "system"
    @AppStorage(SettingsStorageKey.accentColorName) private var accentColorName = "teal"
    @AppStorage(SettingsStorageKey.showEmotionalTags) private var showEmotionalTags = true

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allInsights: [SpendingInsight]

    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    @State private var exportErrorMessage: String?
    @State private var isDeleteConfirmPresented = false
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var isHowItWorksPresented = false

    private let goalRange: ClosedRange<Double> = 5_000...100_000
    private let goalStep: Double = 1_000

    private var messagingCapabilityAvailable: Bool {
        MFMessageComposeViewController.canSendText()
    }

    private var lastScanFormatted: String {
        let ts = UserDefaults.standard.double(forKey: SettingsStorageKey.lastMessageScan)
        guard ts > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: ts)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var dailyNudgeDate: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = dailyNudgeHour
                c.minute = dailyNudgeMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                dailyNudgeHour = parts.hour ?? 8
                dailyNudgeMinute = parts.minute ?? 0
                LocalNotificationScheduler.refreshDailyNudge(
                    enabled: dailyNudgeNotification,
                    hour: dailyNudgeHour,
                    minute: dailyNudgeMinute
                )
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $userFirstName)
                        .textContentType(.givenName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly soft goal")
                            .font(.subheadline.weight(.medium))
                        Text(formattedCurrency(softMonthlyGoal))
                            .font(SpendSenseTypography.money(.title2, weight: .semibold))
                            .monospacedDigit()
                        Slider(value: $softMonthlyGoal, in: goalRange, step: goalStep)
                            .tint(SpendSenseAccent.color(named: accentColorName))
                        HStack {
                            Text(formattedCurrency(goalRange.lowerBound))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(formattedCurrency(goalRange.upperBound))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .onAppear {
                        if !goalRange.contains(softMonthlyGoal) {
                            softMonthlyGoal = min(max(softMonthlyGoal, goalRange.lowerBound), goalRange.upperBound)
                        }
                    }

                    Picker("Currency", selection: $currencyCode) {
                        Text("₹ INR").tag("INR")
                        Text("$ USD").tag("USD")
                        Text("€ EUR").tag("EUR")
                        Text("£ GBP").tag("GBP")
                    }
                } header: {
                    SettingsSectionHeader(title: "Profile")
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Color.secondary.opacity(0.12), in: Circle())
                        Text("All your data lives only on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)

                    Button {
                        openAppSettings()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Message access")
                                    .foregroundStyle(.primary)
                                Text("SMS stack: \(messagingCapabilityAvailable ? "Available" : "Not available")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "",
                                isOn: .constant(messagingCapabilityAvailable)
                            )
                            .labelsHidden()
                            .disabled(true)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportCSV()
                    } label: {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        isDeleteConfirmPresented = true
                    } label: {
                        Label("Delete all data", systemImage: "trash")
                    }

                    HStack {
                        Text("Last scanned messages")
                        Spacer()
                        Text(lastScanFormatted)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    SettingsSectionHeader(title: "Privacy & data")
                }

                Section {
                    Toggle("Weekly insight summary", isOn: $weeklyInsightNotification)
                        .tint(SpendSenseAccent.color(named: accentColorName))
                        .onChange(of: weeklyInsightNotification) { _, on in
                            Task { @MainActor in
                                if on {
                                    let ok = await LocalNotificationScheduler.requestAuthorizationIfNeeded()
                                    if !ok {
                                        weeklyInsightNotification = false
                                    }
                                }
                                await refreshNotificationAuthStatus()
                                LocalNotificationScheduler.refreshWeeklyInsight(enabled: weeklyInsightNotification)
                            }
                        }

                    Text("Sundays at 10:00 — local reminder only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: -4, leading: 20, bottom: 8, trailing: 20))

                    Toggle("Daily morning nudge", isOn: $dailyNudgeNotification)
                        .tint(SpendSenseAccent.color(named: accentColorName))
                        .onChange(of: dailyNudgeNotification) { _, on in
                            Task { @MainActor in
                                if on {
                                    let ok = await LocalNotificationScheduler.requestAuthorizationIfNeeded()
                                    if !ok {
                                        dailyNudgeNotification = false
                                    }
                                }
                                await refreshNotificationAuthStatus()
                                LocalNotificationScheduler.refreshDailyNudge(
                                    enabled: dailyNudgeNotification,
                                    hour: dailyNudgeHour,
                                    minute: dailyNudgeMinute
                                )
                            }
                        }

                    if dailyNudgeNotification {
                        DatePicker(
                            "Time",
                            selection: dailyNudgeDate,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Text(notificationFooterText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    SettingsSectionHeader(title: "Notifications")
                }

                Section {
                    Picker("Theme", selection: $appearanceTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent")
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 14) {
                            ForEach(SpendSenseAccent.optionNames, id: \.self) { name in
                                Button {
                                    accentColorName = name
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(SpendSenseAccent.color(named: name))
                                            .frame(width: 32, height: 32)
                                        if accentColorName == name {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .shadow(radius: 1)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Accent \(name)")
                                .accessibilityAddTraits(accentColorName == name ? .isSelected : [])
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Show emotional tags", isOn: $showEmotionalTags)
                        .tint(SpendSenseAccent.color(named: accentColorName))
                } header: {
                    SettingsSectionHeader(title: "Appearance")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isHowItWorksPresented = true
                    } label: {
                        Text("How SpendSense works")
                    }

                    Text("Open source building blocks: SwiftUI, SwiftData, UserNotifications (local only).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Made with 💛 for personal use")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    SettingsSectionHeader(title: "About")
                }

                #if DEBUG
                Section {
                    Toggle(
                        "Load sample data",
                        isOn: Binding(
                            get: { false },
                            set: { newValue in
                                guard newValue else { return }
                                DeveloperPreviewData.loadSampleData(into: modelContext)
                            }
                        )
                    )
                    Text("Replaces all transactions and insights with 60 preview rows and 5 insights. DEBUG builds only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    SettingsSectionHeader(title: "Developer")
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SpendSensePalette.groupedBackground(for: colorScheme))
            .navigationTitle("Settings")
            .task {
                await refreshNotificationAuthStatus()
            }
            .onAppear {
                LocalNotificationScheduler.refreshWeeklyInsight(enabled: weeklyInsightNotification)
                LocalNotificationScheduler.refreshDailyNudge(
                    enabled: dailyNudgeNotification,
                    hour: dailyNudgeHour,
                    minute: dailyNudgeMinute
                )
            }
            .sheet(isPresented: $isSharePresented) {
                ActivityShareSheet(activityItems: shareItems)
            }
            .sheet(isPresented: $isHowItWorksPresented) {
                HowSpendSenseWorksSheet()
            }
            .alert("Export failed", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .alert("Delete all data?", isPresented: $isDeleteConfirmPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Delete everything", role: .destructive) {
                    SpendSenseHaptics.deleteDataWarning()
                    deleteAllData()
                }
            } message: {
                Text("This removes every transaction, insight, and saved settings on this device. You can’t undo this.")
            }
        }
    }

    private var notificationFooterText: String {
        switch notificationAuthStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are scheduled on this device only — no push or server."
        case .denied:
            return "Notifications are off in Settings. Enable them to receive local reminders."
        default:
            return "Local notifications only — no push tokens or server."
        }
    }

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    private func formattedCurrency(_ value: Double) -> String {
        SpendSenseCurrency.format(amount: value, currencyCode: currencyCode)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func exportCSV() {
        do {
            let url = try SpendSenseCSVExporter.writeTempCSVFile(transactions: Array(allTransactions))
            shareItems = [url]
            isSharePresented = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func deleteAllData() {
        LocalNotificationScheduler.removeAllSpendSenseRequests()
        let txs = allTransactions
        let insights = allInsights
        for tx in txs {
            modelContext.delete(tx)
        }
        for ins in insights {
            modelContext.delete(ins)
        }
        try? modelContext.save()
        for key in SettingsStorageKey.allKeysForNuclearReset {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @MainActor
    private func refreshNotificationAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthStatus = settings.authorizationStatus
    }
}

// MARK: - Section header

private struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - How it works

private struct HowSpendSenseWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        """
                        SpendSense helps you notice patterns in spending — gently, without judgment.

                        When you allow it, the app can look for bank-style SMS patterns locally. Nothing is uploaded or synced to a server. Your soft monthly goal is a compass, not a limit.

                        Insights and summaries are computed on-device from the transactions you keep here.
                        """
                    )
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// Preview: DeveloperPreviewData.swift
