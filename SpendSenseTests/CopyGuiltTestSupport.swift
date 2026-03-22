//
//  CopyGuiltTestSupport.swift
//  SpendSenseTests
//
//  Mirrors `GuiltyWordsList` checks for generated copy (keep lists aligned).
//

import Foundation

enum CopyGuiltTestSupport {
    static let bannedTokens: [String] = [
        "overspent",
        "exceeded",
        "warning",
        "alert",
        "danger",
        "bad"
    ]

    static let bannedPhrases: [String] = [
        "too much"
    ]

    /// First violation found, or `nil` if the copy is clean.
    static func firstViolation(in text: String) -> String? {
        let lower = text.lowercased()
        for phrase in bannedPhrases where lower.contains(phrase) {
            return "phrase:\(phrase)"
        }
        for token in bannedTokens {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            let pattern = "\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(lower.startIndex..., in: lower)
            if regex.firstMatch(in: lower, options: [], range: range) != nil {
                return "token:\(token)"
            }
        }
        return nil
    }
}
