//
//  InsightEngineCopyTests.swift
//  SpendSenseTests
//
//  Banned-word fixtures must stay in sync with `GuiltyWordsList` in the app target.
//

import XCTest

final class InsightEngineCopyTests: XCTestCase {

    /// Mirrors `GuiltyWordsList.bannedTokens` (whole-word match in source scan).
    private let fixtureBannedTokens: [String] = [
        "overspent",
        "exceeded",
        "warning",
        "alert",
        "danger",
        "bad"
    ]

    /// Mirrors `GuiltyWordsList.bannedPhrases` (substring match after lowercasing).
    private let fixtureBannedPhrases: [String] = [
        "too much"
    ]

    func testInsightEngineSourceAvoidsGuiltyLanguage() throws {
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = testDir.deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent("SpendSense/Services/InsightEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let lower = source.lowercased()

        for phrase in fixtureBannedPhrases {
            XCTAssertFalse(
                lower.contains(phrase),
                "Banned phrase \"\(phrase)\" appears in InsightEngine.swift"
            )
        }

        for token in fixtureBannedTokens {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            let pattern = "\\b\(escaped)\\b"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(lower.startIndex..., in: lower)
            let match = regex.firstMatch(in: lower, options: [], range: range)
            XCTAssertNil(
                match,
                "Banned word \"\(token)\" appears as a whole word in InsightEngine.swift"
            )
        }
    }
}
