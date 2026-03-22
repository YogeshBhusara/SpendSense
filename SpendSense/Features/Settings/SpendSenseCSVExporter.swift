//
//  SpendSenseCSVExporter.swift
//  SpendSense
//

import Foundation
import SwiftData

enum SpendSenseCSVExporter {
    static func makeCSV(transactions: [Transaction]) -> String {
        var lines: [String] = [
            "id,amount,merchant,date_iso,category,is_confirmed,emotional_tag,note,raw_message"
        ]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for tx in transactions {
            let dateStr = iso.string(from: tx.date)
            let note = escapeCSV(tx.note ?? "")
            let raw = escapeCSV(tx.rawMessageText)
            let tag = tx.emotionalTag?.rawValue ?? ""
            let line = [
                tx.id.uuidString,
                String(tx.amount),
                escapeCSV(tx.merchant),
                dateStr,
                tx.category.rawValue,
                tx.isConfirmed ? "1" : "0",
                tag,
                note,
                raw
            ].joined(separator: ",")
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    static func writeTempCSVFile(transactions: [Transaction]) throws -> URL {
        let csv = makeCSV(transactions: transactions)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpendSense-export-\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escapeCSV(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return s
    }
}
