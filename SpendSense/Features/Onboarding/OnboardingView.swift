//
//  OnboardingView.swift
//  SpendSense
//

import SwiftUI

enum OnboardingStorageKey {
    static let completed = "hasCompletedOnboarding"
    static let softMonthlyGoal = "softMonthlySpendGoal"
    static let manualEntry = "prefersManualTransactionEntry"
    /// First name for dashboard greeting (optional).
    static let userFirstName = "userFirstName"
}

struct OnboardingView: View {
    @AppStorage(OnboardingStorageKey.completed) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorageKey.softMonthlyGoal) private var softMonthlyGoal = 25_000.0
    @AppStorage(OnboardingStorageKey.manualEntry) private var prefersManualTransactionEntry = false

    @State private var page = 0
    @StateObject private var messageParser = MessageParser()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $page) {
                OnboardingWelcomeScreen(onContinue: { withAnimation { page = 1 } })
                    .tag(0)

                OnboardingPrivacyScreen(onContinue: { withAnimation { page = 2 } })
                    .tag(1)

                OnboardingMessagesScreen(
                    messageParser: messageParser,
                    onGrantContinue: { withAnimation { page = 3 } },
                    onSkip: {
                        prefersManualTransactionEntry = true
                        withAnimation { page = 3 }
                    }
                )
                .tag(2)

                OnboardingGoalScreen(
                    softMonthlyGoal: $softMonthlyGoal,
                    onFinish: {
                        hasCompletedOnboarding = true
                    }
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            OnboardingPageIndicator(current: page, total: 4)
                .padding(.bottom, 28)
        }
    }
}

// MARK: - Page indicator

private struct OnboardingPageIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.primary.opacity(0.18))
                    .frame(width: index == current ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(total)")
    }
}

// MARK: - Screen 1 — Welcome

private struct OnboardingWelcomeScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            welcomeGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                Image(systemName: "indianrupeesign.circle.fill")
                    .font(.system(size: 88))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white.opacity(0.95), .white.opacity(0.35))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    .accessibilityHidden(true)

                Spacer(minLength: 32)

                Text("Know where your money goes")
                    .font(.custom("Georgia", size: 32))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .accessibilityAddTraits(.isHeader)

                Text("SpendSense reads your bank SMSes locally — nothing leaves your phone. Ever.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                Spacer()

                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Let's start")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.35, green: 0.2, blue: 0.12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .accessibilityHint("Goes to privacy information")

                Spacer(minLength: 36)
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                Text("100% on-device")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("100 percent on device")
        }
    }

    private var welcomeGradient: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.09, blue: 0.18),
                        Color(red: 0.04, green: 0.16, blue: 0.19)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.72, blue: 0.38),
                        Color(red: 0.96, green: 0.52, blue: 0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Screen 2 — Privacy Promise

private struct OnboardingPrivacyScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            screenBackdrop

            ScrollView {
                VStack(spacing: 24) {
                    Text("Privacy promise")
                        .font(.custom("Georgia", size: 28))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 0) {
                        privacyRow(
                            icon: "🔒",
                            title: "Only reads, never writes",
                            detail: "We scan messages for spending patterns. We never send messages."
                        )
                        Divider().padding(.leading, 52)
                        privacyRow(
                            icon: "📵",
                            title: "Zero network calls",
                            detail: "No servers, no analytics, no ads. Your data is yours."
                        )
                        Divider().padding(.leading, 52)
                        privacyRow(
                            icon: "🗑️",
                            title: "Delete anytime",
                            detail: "Clear all data from Settings instantly."
                        )
                    }
                    .padding(20)
                    .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 20, y: 10)

                    Button(action: onContinue) {
                        Text("I understand, continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.55, blue: 0.35),
                                        Color(red: 0.92, green: 0.42, blue: 0.45)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .padding(.top, 8)
                    .accessibilityHint("Continue to message access")

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
    }

    private func privacyRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(icon)
                .font(.title2)
                .frame(width: 36, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }

    private var cardBackground: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
            : AnyShapeStyle(Color.white)
    }

    private var screenBackdrop: some View {
        (colorScheme == .dark ? Color.black.opacity(0.92) : Color(red: 0.97, green: 0.95, blue: 0.93))
            .ignoresSafeArea()
    }
}

// MARK: - Screen 3 — Message permission

private struct OnboardingMessagesScreen: View {
    @ObservedObject var messageParser: MessageParser
    let onGrantContinue: () -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            screenBackdrop

            VStack(spacing: 24) {
                Text("Bank SMS")
                    .font(.custom("Georgia", size: 28))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)

                Text("To spot spends automatically, SpendSense looks at transaction texts on your device. Nothing is uploaded — parsing stays on your phone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PhoneSMSMockup()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                Button {
                    messageParser.requestAccess()
                    onGrantContinue()
                } label: {
                    Text("Grant access")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.55, blue: 0.35),
                                    Color(red: 0.92, green: 0.42, blue: 0.45)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .accessibilityHint("Evaluates messaging capability on this device")

                Button("Skip for now", action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .accessibilityHint("Use manual entry for transactions")

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
    }

    private var screenBackdrop: some View {
        (colorScheme == .dark ? Color.black.opacity(0.92) : Color(red: 0.97, green: 0.95, blue: 0.93))
            .ignoresSafeArea()
    }
}

private struct PhoneSMSMockup: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.14),
                            Color(white: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 220, height: 420)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 2)
                        .padding(10)
                }
                .shadow(color: .black.opacity(0.25), radius: 24, y: 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("Messages")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                VStack(alignment: .leading, spacing: 6) {
                    Text("HDFC Bank")
                        .font(.subheadline.weight(.semibold))
                    Text("INR 1,250.00 debited on 12-Mar toward SWIGGY. Avl Bal Rs. 42,300.")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.08)))
            }
            .padding(24)
            .frame(width: 200, height: 380)
            .blur(radius: 5)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Screen 4 — Soft goal

private struct OnboardingGoalScreen: View {
    @Binding var softMonthlyGoal: Double
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let goalRange: ClosedRange<Double> = 5_000...100_000
    private let goalStep: Double = 1_000

    var body: some View {
        ZStack {
            screenBackdrop

            VStack(spacing: 28) {
                Text("Set a soft goal")
                    .font(.custom("Georgia", size: 28))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)

                Text("What's a comfortable monthly spend for you?")
                    .font(.title3.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedRupee(softMonthlyGoal))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Selected amount \(formattedRupee(softMonthlyGoal))")

                Slider(value: $softMonthlyGoal, in: goalRange, step: goalStep)
                    .tint(Color(red: 0.94, green: 0.48, blue: 0.38))
                    .accessibilityLabel("Comfortable monthly spend")

                HStack {
                    Text(formattedRupee(goalRange.lowerBound))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(formattedRupee(goalRange.upperBound))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text("This isn't a hard limit — just a gentle anchor 🪁")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Button(action: onFinish) {
                    Text("Done, show me my spending")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.55, blue: 0.35),
                                    Color(red: 0.92, green: 0.42, blue: 0.45)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .padding(.top, 16)
                .accessibilityHint("Finish onboarding and open the app")

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if !goalRange.contains(softMonthlyGoal) {
                softMonthlyGoal = min(max(softMonthlyGoal, goalRange.lowerBound), goalRange.upperBound)
            }
        }
    }

    private func formattedRupee(_ value: Double) -> String {
        SpendSenseCurrency.format(amount: value, currencyCode: "INR")
    }

    private var screenBackdrop: some View {
        (colorScheme == .dark
            ? SpendSensePalette.backgroundDark.opacity(0.98)
            : SpendSensePalette.backgroundLight)
            .ignoresSafeArea()
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView()
}
