//
//  MessageParser.swift
//  SpendSense
//
//  ---------------------------------------------------------------------------
//  PRIVACY MODEL (README)
//  ---------------------------------------------------------------------------
//  • All SMS text parsing runs in-process on the user’s device.
//  • No network requests are made by this service; nothing is uploaded.
//  • No analytics, crash reporters, or third-party logging of message content.
//  • Parsed output is only handed to the app’s local SwiftData store when you
//    choose to persist it—this class does not transmit data externally.
//  • RELEASE builds may read the local Messages SQLite database from disk when
//    permitted by the OS and user settings (see inline notes); that access is
//    still local-only and never leaves the device from this code path.
//  ---------------------------------------------------------------------------
//

import Combine
import Foundation
import MessageUI
import NaturalLanguage
import SQLite3

// MARK: - Pure parsing + disk read (nonisolated)

private enum MessageParsingEngine {
    struct SMSRow: Sendable {
        let text: String
        let sentAt: Date?
    }

    private static let transactionKeywordPattern: String = {
        let parts = [
            "debited", "spent", "payment of", "charged", "purchase at",
            "transaction of", "paid to", "sent to", "purchase from",
            "inr debited", "rs\\. debited", "a/c debited", "acct debited",
            "upi-", "vpa", "merchant"
        ]
        return "(?i)(" + parts.joined(separator: "|") + ")"
    }()

    private static func containsTransactionSignal(_ text: String) -> Bool {
        if text.range(of: transactionKeywordPattern, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"(?i)\b(hdfc|sbi|icici|axis|kotak|yes bank|pnb|bob|canara)\b"#, options: .regularExpression) != nil,
           text.range(of: #"(?i)(debited|debited\.|credited|spent|payment|upi|txn|transaction)"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    /// Currency amounts: ₹, Rs., INR, $ with optional grouping commas and decimals.
    private static func extractAmount(from text: String) -> Double? {
        let pattern = #"(?i)(?:₹|rs\.?|inr|\$)\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let numeric = String(text[range]).replacingOccurrences(of: ",", with: "")
        return Double(numeric)
    }

    private static func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.compactMap(\.date).first
    }

    private static func extractMerchant(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var candidate: String?

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            guard let tag else { return true }
            if tag == .organizationName || tag == .personalName {
                let slice = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if slice.count >= 2 {
                    candidate = slice
                    return false
                }
            }
            return true
        }

        if let candidate, !candidate.isEmpty { return candidate }

        if let atMerchant = merchantAfterPurchaseAt(in: text) { return atMerchant }

        return "Unknown merchant"
    }

    private static func merchantAfterPurchaseAt(in text: String) -> String? {
        let pattern = #"(?i)purchase\s+(?:at|from)\s+([A-Za-z0-9&'. -]{2,})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func categorize(_ text: String) -> Category {
        let lowered = text.lowercased()
        for (keywords, category) in categoryKeywordMap {
            if keywords.contains(where: { lowered.contains($0) }) {
                return category
            }
        }
        return .other
    }

    /// Earlier entries win if multiple keywords match.
    private static let categoryKeywordMap: [(keywords: [String], category: Category)] = [
        (["swiggy", "zomato", "blinkit", "domino", "mcdonald", "kfc", "eat.fit", "uber eats"], .food),
        (["uber ", "uber-", "ola ", "ola-", "rapido", "nmetro", "irctc", "makemytrip cab"], .transport),
        (["netflix", "spotify", "hotstar", "youtube premium", "apple music", "sonyliv"], .subscriptions),
        (["electricity", "bescom", "mseb", "tata power", "broadband", "airtel postpaid", "jio postpaid", "act fibernet"], .bills),
        (["amazon", "flipkart", "myntra", "nykaa", "meesho"], .shopping),
        (["pvr", "inox", "bookmyshow", "steam", "playstation"], .entertainment),
        (["apollo", "pharmacy", "hospital", "diagnostic", "1mg"], .health),
        (["makemytrip", "goibibo", "ixigo", "air india", "indigo"], .travel)
    ]

    /// - Parameter messageDateFallback: When the body has no detectable date (NSDataDetector), use this (e.g. SQLite `message.date`).
    static func parseMessage(_ text: String, messageDateFallback: Date? = nil) -> Transaction? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        guard let amount = extractAmount(from: normalized) else { return nil }
        guard containsTransactionSignal(normalized) else { return nil }

        let merchant = extractMerchant(from: normalized)
        let date = extractDate(from: normalized) ?? messageDateFallback ?? .now
        let category = categorize(normalized)

        return Transaction(
            amount: amount,
            merchant: merchant,
            rawMessageText: normalized,
            date: date,
            category: category,
            isConfirmed: false,
            emotionalTag: nil,
            note: nil
        )
    }

    static func transactions(from messages: [String], limit: Int) -> [Transaction] {
        let txs: [Transaction] = messages.compactMap { parseMessage($0) }
        var sorted = txs
        sorted.sort { $0.date > $1.date }
        if sorted.count > limit {
            sorted = Array(sorted.prefix(limit))
        }
        return sorted
    }

    static func transactions(fromRows rows: [SMSRow], limit: Int) -> [Transaction] {
        let txs: [Transaction] = rows.compactMap { parseMessage($0.text, messageDateFallback: $0.sentAt) }
        var sorted = txs
        sorted.sort { $0.date > $1.date }
        if sorted.count > limit {
            sorted = Array(sorted.prefix(limit))
        }
        return sorted
    }

    static func debugSimulatedBankMessages() -> [String] {
        [
            "HDFC Bank: INR 1,250.00 debited from A/c XX9012 on 12-Mar-26 towards SWIGGY BANGALORE. Avl Bal Rs. 42,300.50",
            "ICICI: Rs. 499.00 spent on ZOMATO LTD via UPI-1234567890@ybl. Ref 9081726354",
            "Axis Alert: Your a/c is debited for Rs 2,345.50 towards OLA RIDE on 11/03/26. Not you? Call 1800.",
            "SBI: Payment of ₹890.00 charged to card ending 4411 at BLINKIT QUICK COMMERCE.",
            "Kotak: Transaction of Rs. 12,999.00 — purchase at AMAZON PAY on 10 Mar 2026.",
            "HDFC UPI: Rs.175 debited to NETFLIX ENTERTAINMENT. Bal Rs 21000. Ref UPI/77/abc",
            "ICICI: INR 199.00 debited for SPOTIFY INDIA subscription on 09-Mar-2026.",
            "Axis: Payment of Rs 1,050.00 towards BESCOM electricity bill via UPI.",
            "SBI: Rs. 799 charged for JIO POSTPAID broadband bill dated 08-03-2026.",
            "HDFC: Purchase at FLIPKART PAYMENTS for Rs 3,420.00 on 07 Mar 26.",
            "Yes Bank: Rs. 2,199.00 debited — purchase from MYNTRA DESIGNS.",
            "ICICI: Uber trip receipt: Rs. 312.50 debited. Thank you for riding with UBER.",
            "Axis: INR 145.00 spent on RAPIDO BIKE TAXI via UPI.",
            "SBI: Ticket booked IRCTC Rs 1,845.00 debited from A/c.",
            "HDFC: Rs. 499 purchase at BOOKMYSHOW for movie tickets on 05 Mar.",
            "ICICI: Payment of Rs 899.00 to APOLLO PHARMACY — debited.",
            "Kotak: Rs. 15,000.00 debited for MAKE MY TRIP flight booking on 04-Mar-26.",
            "Axis: INR 129.00 charged for HOTSTAR subscription renewal.",
            "SBI: Rs. 2,499.00 transaction of PLAYSTATION NETWORK purchase.",
            "HDFC: Rs. 650.00 debited at DOMINOS PIZZA INDIA — enjoy your meal!"
        ]
    }

    /// Reads `~/Library/SMS/sms.db` when readable (typically **macOS** Messages data).
    ///
    /// **Full Disk Access:** On macOS, System Settings → Privacy & Security → Full Disk Access → add SpendSense
    /// (or Terminal when debugging) so `Library/SMS/sms.db` can be opened. Without it, `sqlite3_open` fails
    /// and this returns an empty list (see ``MessageParser.smsDatabaseUnavailableUserNotice()``).
    ///
    /// On **iOS**, sandboxed App Store apps cannot read this path; expect an empty result and use imports,
    /// Shortcuts, or manual paste flows instead.
    static func readSMSDatabaseRows(limit: Int) -> [SMSRow] {
        let home: URL = {
            #if os(macOS)
            FileManager.default.homeDirectoryForCurrentUser
            #else
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            #endif
        }()
        let url = home.appendingPathComponent("Library/SMS/sms.db", isDirectory: false)

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let database = db else {
            return []
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT text, date
        FROM message
        WHERE text IS NOT NULL AND LENGTH(text) > 0
        ORDER BY date DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let stmt = statement else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var rows: [SMSRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cText = sqlite3_column_text(stmt, 0) else { continue }
            let text = String(cString: cText)
            let rawDate = sqlite3_column_int64(stmt, 1)
            let date = mapAppleMessagesDate(rawDate)
            rows.append(SMSRow(text: text, sentAt: date))
        }

        return rows
    }

    /// Apple stores `message.date` as nanoseconds since 2001-01-01 (reference date) in many DB versions.
    private static func mapAppleMessagesDate(_ raw: Int64) -> Date? {
        guard raw > 0 else { return nil }
        let seconds = TimeInterval(raw) / 1_000_000_000.0
        let candidate = Date(timeIntervalSinceReferenceDate: seconds)
        let years = Calendar.current.dateComponents([.year], from: candidate).year ?? 0
        if (2000...2040).contains(years) { return candidate }

        let unix = Date(timeIntervalSince1970: TimeInterval(raw))
        let y2 = Calendar.current.dateComponents([.year], from: unix).year ?? 0
        if (2000...2040).contains(y2) { return unix }

        return nil
    }
}

// MARK: - Observable service

/// Parses bank / UPI SMS text into `Transaction` drafts.
///
/// **READ-ONLY:** This service never sends, edits, or deletes messages.
/// `MFMessageComposeViewController` is used only to evaluate whether the device
/// can participate in the *Messages / SMS stack* (compose capability). Apple does
/// not provide a public API for third-party iOS apps to read the system SMS inbox;
/// inbox ingestion in RELEASE relies on reading `~/Library/SMS/sms.db` when the
/// process is allowed to (e.g. macOS with Full Disk Access), and otherwise falls
/// back gracefully.
@MainActor
final class MessageParser: ObservableObject {

    @Published private(set) var messagingCapabilityAvailable: Bool = false

    @Published private(set) var lastIngestionNotice: String?

    /// Evaluates messaging surface availability. We **only** read this flag; we
    /// never present a compose UI or write to Messages from this service.
    /// Evaluates whether SMS/MMS can be sent on this device via `MFMessageComposeViewController`.
    /// **READ-ONLY:** We never compose, send, or modify messages—only query capability.
    /// This is **not** an API to read the SMS inbox (Apple does not expose one to third-party iOS apps).
    func requestAccess() {
        messagingCapabilityAvailable = MFMessageComposeViewController.canSendText()
        lastIngestionNotice = nil
    }

    func parseMessage(_ text: String) -> Transaction? {
        MessageParsingEngine.parseMessage(text)
    }

    func fetchRecentMessages(limit: Int) async -> [Transaction] {
        let capped = max(1, limit)

        #if DEBUG
        lastIngestionNotice = nil
        let raw = MessageParsingEngine.debugSimulatedBankMessages()
        let txs = MessageParsingEngine.transactions(from: raw, limit: capped)
        Self.recordLastScan()
        return txs
        #else
        let rows = await Task.detached {
            MessageParsingEngine.readSMSDatabaseRows(limit: capped * 4)
        }.value

        if rows.isEmpty {
            lastIngestionNotice = Self.smsDatabaseUnavailableUserNotice()
        } else {
            lastIngestionNotice = nil
        }

        var txs = MessageParsingEngine.transactions(fromRows: rows, limit: capped * 4)
        if txs.isEmpty, rows.isEmpty == false {
            lastIngestionNotice =
                "Messages were read from disk but none matched spend patterns. Try adjusting keywords or pasting a sample."
        }
        txs.sort { $0.date > $1.date }
        if txs.count > capped {
            txs = Array(txs.prefix(capped))
        }
        if rows.isEmpty == false || txs.isEmpty == false {
            Self.recordLastScan()
        }
        return txs
        #endif
    }

    private static func recordLastScan() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsStorageKey.lastMessageScan)
    }

    private static func smsDatabaseUnavailableUserNotice() -> String {
        """
        Could not read ~/Library/SMS/sms.db. On macOS, grant Full Disk Access to this app in \
        System Settings → Privacy & Security → Full Disk Access, then relaunch. \
        On iOS, the SMS database is not accessible to sandboxed apps—use DEBUG samples, paste, or Shortcuts.
        """
    }
}
