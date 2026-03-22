//
//  InsightEngine.swift
//  SpendSense
//
//  Tone: warm, observational, guilt-free. No shaming language, no alarm-style framing.
//  All copy is local templates — no network / AI calls. (See `GuiltyWordsList` for words we avoid.)
//

import Foundation

@MainActor
final class InsightEngine {

    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - Public

    func generateWeeklyInsights(transactions: [Transaction]) -> [SpendingInsight] {
        let rows = transactions.map(SpendingTransactionRow.init)
        let now = Date()
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        guard let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) else { return [] }
        let lastWeek = DateInterval(start: lastWeekStart, duration: thisWeek.duration)

        let spentThisWeek = SpendingAnalysisCalculator.totalSpent(rows: rows, in: thisWeek)
        let spentLastWeek = SpendingAnalysisCalculator.totalSpent(rows: rows, in: lastWeek)
        let byCategory = SpendingAnalysisCalculator.spentByCategory(rows: rows, in: thisWeek)
        let topCategory = byCategory.max(by: { $0.value < $1.value })

        var insights: [SpendingInsight] = []

        if spentLastWeek > 0, spentThisWeek < spentLastWeek * 0.9 {
            insights.append(makeInsight(
                type: .positiveReinforcement,
                title: pick(["A little lighter this week", "A softer week", "Gentle downward step"], salt: 1),
                body: fill(template: pick(positiveWeekTemplates, salt: 1), [
                    "lastTotal": formatCurrency(spentLastWeek),
                    "thisTotal": formatCurrency(spentThisWeek)
                ])
            ))
        }

        if let topCategory, spentThisWeek > 0, topCategory.value / spentThisWeek >= 0.35 {
            insights.append(makeInsight(
                type: .weeklyHigh,
                title: pick(weeklyHighTitles, salt: 2),
                body: fill(template: pick(weeklyHighBodies, salt: 2), [
                    "category": topCategory.key.displayName,
                    "emoji": topCategory.key.emoji,
                    "amount": formatCurrency(topCategory.value)
                ])
            ))
        }

        if let spike = standoutPurchase(rows: rows, reference: now) {
            insights.append(makeInsight(
                type: .unusualSpike,
                title: pick(unusualSpikeTitles, salt: 3),
                body: fill(template: pick(unusualSpikeBodies, salt: 3), [
                    "amount": formatCurrency(spike.amount),
                    "merchant": spike.merchant
                ])
            ))
        }

        let subscriptionTotal = SpendingAnalysisCalculator.subscriptionTotal(rows: rows)
        let subscriptionRows = rows.filter { $0.category == .subscriptions }
        let subscriptionMerchants = Set(subscriptionRows.map(\.merchant)).count
        if subscriptionTotal > 0, !subscriptionRows.isEmpty {
            insights.append(makeInsight(
                type: .positiveReinforcement,
                title: pick(subscriptionTitles, salt: 4),
                body: fill(template: pick(subscriptionBodies, salt: 4), [
                    "count": String(max(1, subscriptionMerchants)),
                    "total": formatCurrency(subscriptionTotal)
                ])
            ))
        }

        let foodStreak = consecutiveWeeksFoodUnder(rows: rows, cap: 2_000, reference: now)
        if foodStreak >= 3 {
            insights.append(makeInsight(
                type: .positiveReinforcement,
                title: pick(streakTitles, salt: 5),
                body: fill(template: pick(streakBodies, salt: 5), [
                    "weeks": String(foodStreak),
                    "amount": formatCurrency(2_000)
                ])
            ))
        } else if foodStreak < 3, foodShiftUp(rows: rows, reference: now) {
            insights.append(makeInsight(
                type: .streakBreak,
                title: pick(streakBreakTitles, salt: 6),
                body: pick(streakBreakBodies, salt: 6)
            ))
        }

        if spentThisWeek > 0, isQuieterWeek(rows: rows, thisWeek: thisWeek, reference: now) {
            insights.append(makeInsight(
                type: .quietWeek,
                title: pick(quietWeekTitles, salt: 7),
                body: pick(quietWeekBodies, salt: 7)
            ))
        }

        if insights.isEmpty {
            insights.append(makeInsight(
                type: .positiveReinforcement,
                title: pick(defaultWeeklyTitles, salt: 8),
                body: pick(defaultWeeklyBodies, salt: 9)
            ))
        }

        return insights
    }

    func generateDailyNudge(transactions: [Transaction]) -> String {
        let rows = transactions.map(SpendingTransactionRow.init)
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let dayInterval = calendar.dateInterval(of: .day, for: yesterday) else {
            return pick(dailyNudgeNeutral)
        }

        let yesterdaySpend = SpendingAnalysisCalculator.totalSpent(rows: rows, in: dayInterval)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekSpend = weekInterval.map { SpendingAnalysisCalculator.totalSpent(rows: rows, in: $0) } ?? 0
        let foodWeek: Double = {
            guard let w = weekInterval else { return 0 }
            return SpendingAnalysisCalculator.spentByCategory(rows: rows, in: w)[.food] ?? 0
        }()

        var pool = dailyNudgeNeutral
        if yesterdaySpend == 0 {
            pool += dailyNudgeQuietDay
        } else {
            pool += dailyNudgeSpendDay
        }
        if foodWeek > 0 {
            pool += dailyNudgeFood
        }
        if weekSpend == 0 {
            pool += dailyNudgeEmptyWeek
        }

        let template = pick(pool, salt: 10 + calendar.component(.weekday, from: now))
        return fill(template: template, [
            "yesterdayTotal": formatCurrency(yesterdaySpend),
            "weekTotal": formatCurrency(weekSpend)
        ])
    }

    /// Letter-style month narrative for the Insights tab (warm, observational, no scolding).
    func generateMonthSpendingNarrative(transactions: [Transaction], monthContaining reference: Date) -> String {
        let rows = transactions.filter(\.isConfirmed).map(SpendingTransactionRow.init)
        guard let monthInterval = calendar.dateInterval(of: .month, for: reference) else {
            return "Whenever you’re ready, your month’s story will show up here — no rush."
        }

        let monthTotal = SpendingAnalysisCalculator.totalSpent(rows: rows, in: monthInterval)
        if monthTotal == 0 {
            return monthQuietOpening(reference)
        }

        let sortedCats = SpendingAnalysisCalculator.spentByCategory(rows: rows, in: monthInterval)
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }

        let monthName = reference.formatted(.dateTime.month(.wide))
        var paragraphs: [String] = []

        if sortedCats.count >= 2 {
            let first = sortedCats[0]
            let second = sortedCats[1]
            paragraphs.append(
                "\(monthName) had a bit of everything, but \(first.key.displayName.lowercased()) (\(first.key.emoji)) and \(second.key.displayName.lowercased()) (\(second.key.emoji)) did most of the talking."
            )
        } else if let only = sortedCats.first {
            paragraphs.append(
                "\(monthName) leaned gently toward \(only.key.displayName.lowercased()) \(only.key.emoji) — sometimes one theme carries the month, and that’s alright."
            )
        }

        if let spike = biggestSpendingDayInMonth(rows: rows, monthInterval: monthInterval, monthTotal: monthTotal) {
            let dayNum = calendar.component(.day, from: spike.day)
            let ordinal = ordinalDay(dayNum)
            paragraphs.append(
                "You had a fuller day on the \(ordinal) — mostly \(spike.topCategory.displayName.lowercased()) — maybe a planned run, maybe life happening. Either way, it’s a soft spike, not a verdict."
            )
        }

        let subThis = rows.filter { monthInterval.contains($0.date) && $0.category == .subscriptions }
            .reduce(0) { $0 + $1.amount }
        if subThis > 0 {
            if let prevAnchor = calendar.date(byAdding: .month, value: -1, to: reference),
               let prevMonth = calendar.dateInterval(of: .month, for: prevAnchor) {
                let subPrev = rows.filter { prevMonth.contains($0.date) && $0.category == .subscriptions }
                    .reduce(0) { $0 + $1.amount }
                if subPrev <= 0 {
                    paragraphs.append("Subscriptions showed up this stretch — worth a calm glance when you’re curious, not a spreadsheet crisis.")
                } else if subThis < subPrev * 0.92 {
                    paragraphs.append("Subscriptions eased a touch compared with the month before — small shift, nothing dramatic.")
                } else if subThis > subPrev * 1.08 {
                    paragraphs.append("Subscriptions nudged up a little versus last month — information you can sit with.")
                } else {
                    paragraphs.append("Subscriptions stayed fairly flat — the recurring line items kept a familiar rhythm.")
                }
            } else {
                paragraphs.append("Subscriptions hummed along in the background — steady little threads in the pattern.")
            }
        }

        paragraphs.append(
            "Altogether, about \(formatCurrency(monthTotal)) moved through the month — you’re simply reading the shape of it, together with past-you."
        )

        return paragraphs.joined(separator: "\n\n")
    }

    private func monthQuietOpening(_ reference: Date) -> String {
        let monthName = reference.formatted(.dateTime.month(.wide))
        return "\(monthName) looks quiet on the ledger — maybe you were elsewhere, maybe spends landed in other ways. However the month felt, the numbers aren’t the whole story."
    }

    private func ordinalDay(_ n: Int) -> String {
        let suffix: String
        switch n {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    private func biggestSpendingDayInMonth(
        rows: [SpendingTransactionRow],
        monthInterval: DateInterval,
        monthTotal: Double
    ) -> (day: Date, topCategory: Category)? {
        var byDay: [Date: (total: Double, byCat: [Category: Double])] = [:]
        for row in rows where monthInterval.contains(row.date) {
            let d = calendar.startOfDay(for: row.date)
            var entry = byDay[d] ?? (0, [:])
            entry.total += row.amount
            entry.byCat[row.category, default: 0] += row.amount
            byDay[d] = entry
        }
        guard let maxDay = byDay.max(by: { $0.value.total < $1.value.total }),
              maxDay.value.total >= monthTotal * 0.18,
              let topCat = maxDay.value.byCat.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        return (maxDay.key, topCat)
    }

    // MARK: - Builders

    private func makeInsight(type: InsightType, title: String, body: String) -> SpendingInsight {
        SpendingInsight(type: type, title: title, body: body, createdAt: .now, isRead: false)
    }

    private func formatCurrency(_ value: Double) -> String {
        let code = UserDefaults.standard.string(forKey: SettingsStorageKey.currencyCode) ?? "INR"
        return SpendSenseCurrency.format(amount: value, currencyCode: code)
    }

    private func fill(template: String, _ values: [String: String]) -> String {
        values.reduce(template) { partial, pair in
            partial.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    private func pick(_ options: [String], salt: Int = 0) -> String {
        guard !options.isEmpty else { return "" }
        let day = calendar.component(.day, from: Date())
        let month = calendar.component(.month, from: Date())
        let index = abs(day + month * 31 + salt * 17) % options.count
        return options[index]
    }

    // MARK: - Light analysis helpers

    private func standoutPurchase(rows: [SpendingTransactionRow], reference: Date) -> SpendingTransactionRow? {
        guard let windowStart = calendar.date(byAdding: .day, value: -30, to: reference) else { return nil }
        let window = DateInterval(start: windowStart, end: reference)
        let recent = rows.filter { window.contains($0.date) }
        guard let candidate = recent.max(by: { $0.amount < $1.amount }) else { return nil }

        let sameCategory = rows.filter { $0.category == candidate.category }
        let average = sameCategory.isEmpty ? 0 : sameCategory.reduce(0) { $0 + $1.amount } / Double(sameCategory.count)
        guard average > 0, candidate.amount >= average * 2 else { return nil }
        return candidate
    }

    private func consecutiveWeeksFoodUnder(rows: [SpendingTransactionRow], cap: Double, reference: Date) -> Int {
        var streak = 0
        for offset in 0..<12 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: reference),
                  let week = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { continue }
            let hadActivity = rows.contains { week.contains($0.date) }
            if !hadActivity { continue }
            let food = rows
                .filter { week.contains($0.date) && $0.category == .food }
                .reduce(0) { $0 + $1.amount }
            if food < cap {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func foodShiftUp(rows: [SpendingTransactionRow], reference: Date) -> Bool {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: reference),
              let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) else {
            return false
        }
        let prevWeek = DateInterval(start: prevStart, duration: thisWeek.duration)
        let foodThis = rows.filter { thisWeek.contains($0.date) && $0.category == .food }.reduce(0) { $0 + $1.amount }
        let foodPrev = rows.filter { prevWeek.contains($0.date) && $0.category == .food }.reduce(0) { $0 + $1.amount }
        return foodPrev > 0 && foodThis > foodPrev * 1.25
    }

    private func isQuieterWeek(rows: [SpendingTransactionRow], thisWeek: DateInterval, reference: Date) -> Bool {
        var totals: [Double] = []
        for offset in 1..<6 {
            guard let anchor = calendar.date(byAdding: .weekOfYear, value: -offset, to: reference),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: anchor) else { continue }
            totals.append(SpendingAnalysisCalculator.totalSpent(rows: rows, in: interval))
        }
        guard !totals.isEmpty else { return false }
        let mean = totals.reduce(0, +) / Double(totals.count)
        let this = SpendingAnalysisCalculator.totalSpent(rows: rows, in: thisWeek)
        return mean > 0 && this < mean * 0.85
    }

    // MARK: - Template banks (30+ unique strings)

    private let positiveWeekTemplates: [String] = [
        "Quieter week than usual — feels good, doesn't it? 🌿",
        "A softer rhythm showed up in the numbers — nice breathing room.",
        "This stretch looked a little calmer than the last one. Just an observation ☕",
        "Less movement on the spend side this week — sometimes that’s its own kind of win.",
        "A gentle dip compared to last week — worth noticing without overthinking it.",
        "The week had a lighter footprint — however you spent your time, hope it felt good.",
        "A bit less outflow than before — small shifts add up in quiet ways 🌙"
    ]

    private let weeklyHighTitles: [String] = [
        "A theme showed up",
        "This week had a flavor",
        "One category led the way",
        "A little cluster here"
    ]

    private let weeklyHighBodies: [String] = [
        "Looks like this week was a {category}-heavy one {emoji} — mostly just a pattern, not a verdict.",
        "{category} carried a good share of the week ({amount}) — interesting to see where energy went.",
        "A chunk of the week leaned toward {category} ({amount}) — sometimes weeks have a favorite category.",
        "{category} popped up more than usual ({amount}) — could be routine, could be life — either way, you’re informed."
    ]

    private let unusualSpikeTitles: [String] = [
        "One purchase stood out",
        "A bigger blip",
        "Something caught the eye",
        "A standout moment"
    ]

    private let unusualSpikeBodies: [String] = [
        "That {amount} at {merchant} stands out this month — treat-yourself moment? 🛍️",
        "{merchant} for {amount} is a little louder than your usual mix — maybe a planned splurge, maybe a story behind it.",
        "Noticing {amount} at {merchant} — bigger than typical, and that can be totally okay.",
        "{merchant} at {amount} rose above the usual noise — worth a glance, not a guilt trip."
    ]

    private let subscriptionTitles: [String] = [
        "Subscriptions, in one place",
        "Recurring bits",
        "The steady line items"
    ]

    private let subscriptionBodies: [String] = [
        "You’re running about {count} subscription-style merchants totaling {total}/month in the data — worth a scroll when you’re curious?",
        "Roughly {count} recurring threads add up to {total} — a calm moment to see what still sparks joy.",
        "Subscriptions land around {total} across {count} merchants — gentle nudge to revisit what you love using.",
        "{total} is the subscription-shaped slice right now — totally fine to keep, tweak, or just notice."
    ]

    private let streakTitles: [String] = [
        "Nice little streak",
        "Food spend: steady",
        "A calm food rhythm"
    ]

    private let streakBodies: [String] = [
        "{weeks} weeks in a row you've kept food spend under {amount} 🎉",
        "{weeks} weeks running with food under {amount} — soft consistency, nicely done.",
        "Food has stayed under {amount} for {weeks} weeks — gentle structure showing up.",
        "{weeks} weeks under {amount} on food — small pattern, kind of satisfying."
    ]

    private let streakBreakTitles: [String] = [
        "A little more dining energy",
        "Food popped up a bit",
        "Weeks shift sometimes"
    ]

    private let streakBreakBodies: [String] = [
        "Food spend edged up compared with your last few weeks — variety counts too.",
        "A touch more food activity this week — seasons change, cravings change, all fair.",
        "Your food line looks a bit fuller lately — could be plans, people, or plain hunger. No story needed.",
        "Patterns breathe — this week had a little more food flavor than the last stretch."
    ]

    private let quietWeekTitles: [String] = [
        "Soft week overall",
        "Gentle on the totals",
        "A quieter rhythm"
    ]

    private let quietWeekBodies: [String] = [
        "Compared with your recent weeks, this one ran a little lighter — however that lands for you.",
        "Totals came in softer than your usual few weeks — nice if you were aiming for ease.",
        "A calmer week versus your running average — observation, not instruction 🌿",
        "Spend looked a touch shy of your recent pace — room to breathe, if that’s what you wanted."
    ]

    private let defaultWeeklyTitles: [String] = [
        "Checking in",
        "A small snapshot",
        "Your week, in numbers"
    ]

    private let defaultWeeklyBodies: [String] = [
        "Nothing dramatic jumped out — you’re simply keeping the thread visible.",
        "Steady data, calm read — you’re all caught up.",
        "A quiet dashboard is still a useful one — you’re in the loop.",
        "No big story this week — sometimes that’s the whole story."
    ]

    private let dailyNudgeNeutral: [String] = [
        "Morning — here’s a gentle read on yesterday, no pressure attached.",
        "A soft check-in: your numbers are here when you want them.",
        "Hope the day starts kind — your spend story is just context, not a score.",
        "Small hello 👋 however yesterday looked, you’re still doing the human thing."
    ]

    private let dailyNudgeQuietDay: [String] = [
        "Yesterday was easy on the wallet 🌙",
        "Yesterday looked pretty quiet spend-wise — however you spent your day, hope it felt good.",
        "Not much movement yesterday — calm days count too.",
        "A gentle zero-ish day on the spend side — breathe-in energy."
    ]

    private let dailyNudgeSpendDay: [String] = [
        "Yesterday had a little activity ({yesterdayTotal}) — information, not judgment.",
        "About {yesterdayTotal} moved yesterday — just keeping you in the loop.",
        "Yesterday’s total landed around {yesterdayTotal} — you’re informed, that’s all.",
        "{yesterdayTotal} yesterday — a fact, not a verdict."
    ]

    private let dailyNudgeFood: [String] = [
        "Couple of taps on Swiggy this week — no judgment, just keeping you in the loop.",
        "Food deliveries might have said hello this week — curiosity, not critique.",
        "If food apps chimed in this week, that’s noted — your call what to do with it.",
        "Food orders might have dotted the week — you’re allowed convenience."
    ]

    private let dailyNudgeEmptyWeek: [String] = [
        "The week’s been light so far — however that feels, it’s valid.",
        "Quiet week totals — maybe life happened offline, which is lovely too.",
        "Not much on the ledger yet this week — room still writing itself."
    ]
}
