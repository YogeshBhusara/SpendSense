//
//  GuiltyWordsList.swift
//  SpendSense
//
//  SpendSense copy should stay warm and non-judgmental. These words and phrases
//  are avoided in user-facing strings (especially `InsightEngine`).
//
//  Softer alternatives (use contextually):
//  - "overspent" → "went a bit past your soft anchor" / "landed above the gentle line"
//  - "exceeded" → "moved past" / "went a little beyond"
//  - "warning" → "heads-up" / "something to notice" / "gentle ping"
//  - "alert" → "nudge" / "reminder" / "check-in"
//  - "danger" → "worth a second look" / "unusual blip"
//  - "bad" → "heavier" / "busier" / "fuller" (for spend), or reframe without judgment
//  - "too much" → "more than usual" / "a fuller slice" / "a bit more than before"
//

import Foundation

enum GuiltyWordsList {
    // When you edit these arrays, mirror the same values in `SpendSenseTests/InsightEngineCopyTests.swift`
    // so the copy-audit test stays accurate (tests link XCTest only and cannot import app symbols).

    /// Single-token banned words (matched as whole words in source scans).
    static let bannedTokens: [String] = [
        "overspent",
        "exceeded",
        "warning",
        "alert",
        "danger",
        "bad"
    ]

    /// Multi-word phrases to avoid (matched as substrings after lowercasing).
    static let bannedPhrases: [String] = [
        "too much"
    ]
}
