//
//  ManualTransactionEntrySheet.swift
//  SpendSense
//

import SwiftData
import SwiftUI

struct ManualTransactionEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var merchant: String = ""
    @State private var date: Date = .now
    @State private var category: Category = .other
    @State private var emotionalTag: EmotionalTag?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g. 1250", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(SpendSenseTypography.money(.title2, weight: .semibold))
                            .monospacedDigit()
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Merchant")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Where was this?", text: $merchant)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Category.allCases, id: \.self) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text("\(cat.emoji) \(cat.displayName)")
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(category == cat
                                                        ? Color.accentColor.opacity(0.22)
                                                        : Color(.secondarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(
                                                        category == cat ? Color.accentColor.opacity(0.5) : Color.clear,
                                                        lineWidth: 1.5
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Emotional tag (optional)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                            tagButton(.impulse, "Impulse")
                            tagButton(.essential, "Essential")
                            tagButton(.treat, "Treat")
                            tagButton(.subscription, "Subscription")
                        }
                        Button("No tag") {
                            emotionalTag = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(parsedAmount == nil || merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var parsedAmount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    private func tagButton(_ tag: EmotionalTag, _ label: String) -> some View {
        let selected = emotionalTag == tag
        return Button {
            emotionalTag = emotionalTag == tag ? nil : tag
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let amt = parsedAmount else { return }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let tx = Transaction(
            amount: amt,
            merchant: name,
            rawMessageText: "",
            date: date,
            category: category,
            isConfirmed: true,
            emotionalTag: emotionalTag,
            note: nil
        )
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
    }
}

// Preview: DeveloperPreviewData.swift
