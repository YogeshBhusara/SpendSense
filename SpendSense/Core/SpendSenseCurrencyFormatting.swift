//
//  SpendSenseCurrencyFormatting.swift
//  SpendSense
//
//  Indian grouping (e.g. ₹1,23,456) via `en_IN` for INR; locale-aware for other codes.
//

import Foundation

enum SpendSenseCurrency {
    static func locale(for currencyCode: String) -> Locale {
        switch currencyCode.uppercased() {
        case "INR": Locale(identifier: "en_IN")
        case "USD": Locale(identifier: "en_US")
        case "EUR": Locale(identifier: "en_DE")
        case "GBP": Locale(identifier: "en_GB")
        default: Locale.current
        }
    }

    static func formatter(currencyCode: String, maximumFractionDigits: Int = 0) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode.uppercased()
        f.locale = locale(for: currencyCode)
        f.maximumFractionDigits = maximumFractionDigits
        return f
    }

    static func format(amount: Double, currencyCode: String, maximumFractionDigits: Int = 0) -> String {
        let code = currencyCode.uppercased()
        let formatted = formatter(currencyCode: code, maximumFractionDigits: maximumFractionDigits)
            .string(from: NSNumber(value: amount))
        if let formatted { return formatted }
        if maximumFractionDigits > 0 {
            return String(format: "%.2f", amount)
        }
        return code == "INR" ? "₹\(Int(amount))" : "\(Int(amount))"
    }
}
