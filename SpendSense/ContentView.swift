//
//  ContentView.swift
//  SpendSense
//
//  Created by Yogesh Bhusara on 22/03/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.pie.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
