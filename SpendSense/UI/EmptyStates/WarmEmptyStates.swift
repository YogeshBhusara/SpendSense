//
//  WarmEmptyStates.swift
//  SpendSense
//

import SwiftUI

struct DashboardTransactionsEmptyState: View {
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Image(systemName: "message.and.waveform.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .offset(x: -18, y: 6)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.68, blue: 0.52),
                                Color(red: 0.32, green: 0.55, blue: 0.48)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(breathe ? 1.05 : 0.96)
            .rotationEffect(.degrees(breathe ? 2.5 : -2.5))
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)

            Text("Nothing here yet — once your bank SMSes arrive, I'll start putting the picture together 🌱")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onAppear { breathe = true }
        .accessibilityElement(children: .combine)
    }
}

struct InsightsPatternsEmptyState: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 58))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.52, blue: 0.85),
                            Color(red: 0.42, green: 0.48, blue: 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulse ? 1.06 : 0.94)
                .opacity(pulse ? 1 : 0.82)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)

            Text("Give it a week — I'll start noticing patterns soon 🔍")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .onAppear { pulse = true }
        .accessibilityElement(children: .combine)
    }
}

struct AllTransactionsEmptyState: View {
    @State private var wiggle = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(wiggle ? 4 : -4))
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: wiggle)

            Text("No transactions yet — your list will grow gently as you confirm spends.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { wiggle = true }
    }
}
