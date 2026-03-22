//
//  AllTransactionsView.swift
//  SpendSense
//

import SwiftUI

struct AllTransactionsView: View {
    let transactions: [Transaction]
    var currencyCode: String = "INR"

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }

    var body: some View {
        Group {
            if transactions.isEmpty {
                AllTransactionsEmptyState()
            } else {
                List(transactions, id: \.id) { tx in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tx.merchant)
                                .font(.headline)
                            HStack(spacing: 6) {
                                Text(tx.category.emoji)
                                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(currencyFormatter.string(from: NSNumber(value: tx.amount)) ?? "—")
                            .font(SpendSenseTypography.money(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("All transactions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
