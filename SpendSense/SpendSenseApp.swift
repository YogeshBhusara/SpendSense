//
//  SpendSenseApp.swift
//  SpendSense
//
//  Created by Yogesh Bhusara on 22/03/26.
//

import SwiftData
import SwiftUI

@main
struct SpendSenseApp: App {
    /// Local-only SwiftData store (no CloudKit sync).
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            SpendingInsight.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SpendSense: could not create ModelContainer — \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.makeModelContainer())
    }
}

private struct RootView: View {
    @AppStorage(OnboardingStorageKey.completed) private var hasCompletedOnboarding = false
    @AppStorage(SettingsStorageKey.appearanceTheme) private var appearanceTheme = "system"
    @AppStorage(SettingsStorageKey.accentColorName) private var accentColorName = "teal"

    private var resolvedAccentName: String {
        accentColorName == "lavender" ? "sage" : accentColorName
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .tint(SpendSenseAccent.color(named: resolvedAccentName))
        .onAppear {
            if accentColorName == "lavender" {
                accentColorName = "sage"
            }
        }
    }
}
