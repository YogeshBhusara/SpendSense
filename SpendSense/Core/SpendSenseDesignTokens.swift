//
//  SpendSenseDesignTokens.swift
//  SpendSense
//
//  Visual language: warm, personal, non-judgmental — like a financially aware friend, not a bank app.
//  Spending data never uses red; use coral/amber for “higher than usual” and teal/sage for calm / on-track.
//

import SwiftUI

// MARK: - Palette (brand accents + surfaces)

enum SpendSensePalette {
    static let warmTeal = Color(red: 45 / 255, green: 212 / 255, blue: 191 / 255) // #2DD4BF
    static let softCoral = Color(red: 251 / 255, green: 113 / 255, blue: 133 / 255) // #FB7185
    static let amber = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255) // #FBBF24
    static let sage = Color(red: 134 / 255, green: 239 / 255, blue: 172 / 255) // #86EFAC

    static let backgroundLight = Color(red: 250 / 255, green: 250 / 255, blue: 249 / 255) // #FAFAF9
    static let cardLight = Color.white // #FFFFFF
    static let backgroundDark = Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255) // #0F0F0F
    static let cardDark = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255) // #1C1C1E

    static func groupedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? backgroundDark : backgroundLight
    }

    static func cardSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardDark : cardLight
    }
}

// MARK: - Semantic spending colors (no red)

enum SpendSenseSemanticColor {
    /// Under budget, down vs prior, or “all good” — teal / sage family
    static let onTrack = SpendSensePalette.warmTeal
    static let onTrackMuted = SpendSensePalette.sage

    /// Higher vs last week / baseline — warm heads-up (coral + amber), never alarm red
    static let elevatedSpend = SpendSensePalette.softCoral
    static let elevatedSpendWarm = SpendSensePalette.amber
}

// MARK: - Layout (8pt grid)

enum SpendSenseLayout {
    static let unit: CGFloat = 8
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32

    static let chipCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let heroCornerRadius: CGFloat = 24
}

// MARK: - Card shadow

private struct SpendSenseCardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    /// Standard SpendSense drop shadow for elevated cards.
    func spendSenseCardShadow() -> some View {
        modifier(SpendSenseCardShadowModifier())
    }
}

// MARK: - Card shells

private struct SpendSenseCardShellModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let addShadow: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if addShadow {
                content
                    .background(shape.fill(SpendSensePalette.cardSurface(for: colorScheme)))
                    .spendSenseCardShadow()
            } else {
                content
                    .background(shape.fill(SpendSensePalette.cardSurface(for: colorScheme)))
            }
        }
    }
}

extension View {
    /// Filled card surface (light/dark) + optional standard shadow.
    func spendSenseCardSurface(cornerRadius: CGFloat = SpendSenseLayout.cardCornerRadius, shadow: Bool = true) -> some View {
        modifier(SpendSenseCardShellModifier(cornerRadius: cornerRadius, addShadow: shadow))
    }
}

// MARK: - Typography (SF Pro Text body, SF Pro Rounded for money / key figures)

enum SpendSenseTypography {
    /// Body and labels — SF Pro Text (system default design).
    static func text(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default).weight(weight)
    }

    /// Amounts and hero numerals — SF Pro Rounded.
    static func money(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func money(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

// MARK: - Hex (category / tag strings)

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
