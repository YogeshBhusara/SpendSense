//
//  TransactionConfirmationTray.swift
//  SpendSense
//

import SwiftData
import SwiftUI

// MARK: - Tray (sheet content)

struct TransactionConfirmationTrayContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<Transaction> { $0.isConfirmed == false },
        sort: [SortDescriptor(\.date, order: .reverse)]
    )
    private var unconfirmed: [Transaction]

    @State private var activeConfirmation: ActiveConfirmationDraft?
    @State private var ignoringId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if unconfirmed.isEmpty, activeConfirmation == nil {
                    confirmationEmptyState
                } else {
                    let visible = unconfirmed.filter { tx in
                        tx.id != ignoringId && tx.id != activeConfirmation?.id
                    }
                    VStack(spacing: 20) {
                        headerCopy

                        if visible.isEmpty, activeConfirmation != nil {
                            Text("Finish picking category and tags in the sheet — your card will return here if you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else {
                            SwipeTransactionCardStack(
                                transactions: visible,
                                onConfirmSwipe: { tx in
                                    activeConfirmation = ActiveConfirmationDraft(transaction: tx)
                                },
                                onIgnore: { tx in
                                    ignoreTransaction(tx)
                                }
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $activeConfirmation) { draft in
                ConfirmTransactionDetailView(
                    transaction: draft.transaction,
                    initialNote: draft.transaction.note ?? ""
                )
            }
        }
    }

    private var headerCopy: some View {
        VStack(spacing: 8) {
            Text("A few new transactions to review 👀")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Swipe right to confirm, left to ignore")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var confirmationEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(SpendSensePalette.sage.opacity(0.55))
                    .offset(x: -8, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(SpendSensePalette.amber.opacity(0.9))
                    .offset(x: 28, y: -18)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(SpendSensePalette.warmTeal.opacity(0.65))
                    .offset(x: 6, y: 8)
            }
            .frame(height: 100)
            .accessibilityHidden(true)

            Text("All caught up! ✨")
                .font(.title2.weight(.semibold))
            Text("No new transactions to review.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func ignoreTransaction(_ tx: Transaction) {
        ignoringId = tx.id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            modelContext.delete(tx)
            try? modelContext.save()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            ignoringId = nil
        }
    }
}

// MARK: - Sheet item for detail step

struct ActiveConfirmationDraft: Identifiable {
    var id: UUID { transaction.id }
    let transaction: Transaction
}

// MARK: - Swipe stack

private struct SwipeTransactionCardStack: View {
    let transactions: [Transaction]
    let onConfirmSwipe: (Transaction) -> Void
    let onIgnore: (Transaction) -> Void

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(transactions.prefix(4).enumerated()), id: \.element.id) { index, tx in
                    SwipeTransactionCard(
                        transaction: tx,
                        isTop: index == 0,
                        stackIndex: index,
                        screenWidth: geo.size.width,
                        swipeThreshold: swipeThreshold,
                        onSwipeRight: {
                            onConfirmSwipe(tx)
                        },
                        onSwipeLeft: {
                            onIgnore(tx)
                        }
                    )
                    .zIndex(Double(transactions.count - index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 420)
    }
}

// MARK: - Single swipe card

private struct SwipeTransactionCard: View {
    let transaction: Transaction
    let isTop: Bool
    let stackIndex: Int
    let screenWidth: CGFloat
    let swipeThreshold: CGFloat
    let onSwipeRight: () -> Void
    let onSwipeLeft: () -> Void

    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"

    @State private var drag: CGSize = .zero
    @State private var flyOff: FlyDirection?

    private enum FlyDirection {
        case right, left
    }

    var body: some View {
        let progress = drag.width / swipeThreshold
        let greenTint = max(0, min(1, progress)) * 0.14
        let grayTint = max(0, min(1, -progress)) * 0.12

        cardContent
            .background(
                RoundedRectangle(cornerRadius: SpendSenseLayout.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: SpendSenseLayout.cardCornerRadius, style: .continuous)
                            .fill(SpendSensePalette.warmTeal.opacity(greenTint))
                        RoundedRectangle(cornerRadius: SpendSenseLayout.cardCornerRadius, style: .continuous)
                            .fill(Color.gray.opacity(grayTint))
                    }
            )
            .overlay { flyOverlay }
            .scaleEffect(1 - CGFloat(stackIndex) * 0.045)
            .offset(y: CGFloat(stackIndex) * 10)
            .offset(x: flyX)
            .rotationEffect(.degrees(Double(drag.width / 25)))
            .opacity(isTop ? 1 : 0.92)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: drag)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: flyOff)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard isTop, flyOff == nil else { return }
                        drag = value.translation
                    }
                    .onEnded { value in
                        guard isTop else { return }
                        handleEnd(translation: value.translation)
                    }
            )
            .allowsHitTesting(isTop && flyOff == nil)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.merchant)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Text(currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? "—")
                    .font(SpendSenseTypography.money(.title3, weight: .bold))
                    .monospacedDigit()
            }

            Text(transaction.date.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Original message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(transaction.rawMessageText.isEmpty ? "—" : transaction.rawMessageText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .padding(20)
    }

    @ViewBuilder
    private var flyOverlay: some View {
        switch flyOff {
        case .right:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(SpendSensePalette.warmTeal.opacity(0.95))
                .transition(.scale.combined(with: .opacity))
        case .left:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.gray.opacity(0.75))
                .transition(.scale.combined(with: .opacity))
        case nil:
            if drag.width > 24 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SpendSensePalette.warmTeal.opacity(0.35 + min(0.45, drag.width / 200)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(24)
            } else if drag.width < -24 {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.gray.opacity(0.35 + min(0.4, -drag.width / 200)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(24)
            }
        }
    }

    private var flyX: CGFloat {
        switch flyOff {
        case .right: return screenWidth * 1.2
        case .left: return -screenWidth * 1.2
        case nil: return drag.width
        }
    }

    private func handleEnd(translation: CGSize) {
        if translation.width > swipeThreshold {
            SpendSenseHaptics.swipeConfirmSuccess()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                flyOff = .right
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                drag = .zero
                flyOff = nil
                onSwipeRight()
            }
        } else if translation.width < -swipeThreshold {
            SpendSenseHaptics.swipeDismissLight()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                flyOff = .left
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                drag = .zero
                flyOff = nil
                onSwipeLeft()
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                drag = .zero
            }
        }
    }

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }
}

// MARK: - Confirm detail (category, tag, note)

struct ConfirmTransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsStorageKey.currencyCode) private var currencyCode = "INR"

    @Bindable var transaction: Transaction
    @State private var noteText: String

    init(transaction: Transaction, initialNote: String) {
        self.transaction = transaction
        _noteText = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transaction.merchant)
                            .font(.title2.weight(.semibold))
                        Text(currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? "—")
                            .font(SpendSenseTypography.money(.title3, weight: .bold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Category.allCases, id: \.self) { cat in
                                    Button {
                                        transaction.category = cat
                                    } label: {
                                        Text("\(cat.emoji) \(cat.displayName)")
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(transaction.category == cat
                                                        ? Color.accentColor.opacity(0.22)
                                                        : Color(.secondarySystemGroupedBackground))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(
                                                        transaction.category == cat ? Color.accentColor.opacity(0.5) : Color.clear,
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
                        Text("How did this feel?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            emotionalChip(.impulse, label: "Impulse")
                            emotionalChip(.essential, label: "Essential")
                            emotionalChip(.treat, label: "Treat")
                            emotionalChip(.subscription, label: "Subscription")
                        }
                        Button("Clear tag") {
                            transaction.emotionalTag = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a note…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("Optional note", text: $noteText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func emotionalChip(_ tag: EmotionalTag, label: String) -> some View {
        let selected = transaction.emotionalTag == tag
        return Button {
            transaction.emotionalTag = transaction.emotionalTag == tag ? nil : tag
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: SpendSenseLayout.chipCornerRadius, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SpendSenseLayout.chipCornerRadius, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        transaction.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText
        transaction.isConfirmed = true
        try? modelContext.save()
        SpendSenseHaptics.transactionConfirmed()
        dismiss()
    }

    private var currencyFormatter: NumberFormatter {
        SpendSenseCurrency.formatter(currencyCode: currencyCode, maximumFractionDigits: 0)
    }
}

// MARK: - Preview

// Preview: DeveloperPreviewData.swift
