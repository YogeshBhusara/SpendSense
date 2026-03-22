# SpendSense

**SpendSense** is an iOS app for tracking spending with a **local-first, privacy-focused** design. It helps you capture transactions from everyday bank/UPI SMS (where supported), reflect on patterns with gentle insights, and keep your financial life on your device—not in someone else’s cloud.

---

## Why this app?

- **Frictionless capture:** Many purchases show up first as SMS alerts. SpendSense is built around parsing those messages on-device so you spend less time retyping amounts and merchants.
- **Awareness, not anxiety:** Dashboard, categories, and insights are meant to support mindful spending (including optional emotional tags), not to replace a bank statement or professional advice.
- **You own the data:** There is no account system and no sync layer shipping your transactions to a backend. What you enter or import stays in your local store unless **you** export or share it.

---

## Why privacy matters

SpendSense is intentionally **private by design**:

- **SwiftData** stores transactions and insights **only on your iPhone** (no CloudKit sync in the shipping configuration).
- **SMS-related parsing** runs **on-device**. The codebase does not send message text or parsed results to external analytics or servers for that flow.
- You choose what to keep: confirm or edit parsed items, use **manual entry** if you prefer not to grant Messages access, and use **Settings** to export or delete data when you want.

That matters because spending and SMS content are **highly sensitive**. Keeping them local reduces exposure and keeps you in control.

---

## Features

| Area | What it does |
|------|----------------|
| **Home** | Dashboard of spending, categories, and transaction flow |
| **Insights** | Spending insights derived from your local data |
| **Settings** | Currency, appearance, accent, goals, notifications, CSV export, optional data reset |
| **Onboarding** | Welcome, privacy explanation, Messages access or **skip → manual entry**, soft monthly goal |
| **Widget** | **SpendSenseWidget** target for at-a-glance snapshots (where configured) |

Parsing is tuned for common **Indian banking / UPI** style SMS keywords and amounts (₹, Rs., INR, etc.). Results depend on message wording and OS access; always review before treating something as authoritative.

---

## Requirements

- **Xcode** (recent stable release recommended)
- **iOS 17.0+** deployment target
- **Swift 5**

---

## Getting started

1. Clone or open this folder in Xcode.
2. Open **`SpendSense.xcodeproj`**.
3. Select the **SpendSense** scheme and a physical device or simulator (some Messages-related behavior is **device- and permission-dependent**).
4. Build and run (**⌘R**).

Unit tests live under **`SpendSenseTests`** (e.g. message parsing, insight engine, spending analyzer).

---

## Usage

1. **First launch:** Complete onboarding—read the privacy screen, then either allow Messages-related flow for SMS-assisted capture or **skip** to use **manual transaction entry** only.
2. **Home tab:** Review totals, categories, and individual transactions; confirm or adjust parsed items as needed.
3. **Insights tab:** Explore patterns from data already on your device.
4. **Settings:** Adjust theme, accent, currency, optional **weekly / daily notifications**, export **CSV** if you want a copy outside the app, or use **delete all data** for a full reset.

**Important:** SpendSense is a **personal productivity and awareness tool**. It is **not** financial, legal, or tax advice, and it is **not** a substitute for your bank’s official records.

---

## Project layout (high level)

```
SpendSense/
├── SpendSense/           # Main app (SwiftUI + SwiftData)
│   ├── Core/             # Design tokens, formatting, haptics, widget snapshot, etc.
│   ├── Features/       # Dashboard, Insights, Onboarding, Settings, Transactions
│   ├── Models/         # Transaction, Category, insights, tags
│   ├── Services/       # Message parsing, spending analysis, insight engine
│   └── UI/             # Shared UI pieces
├── SpendSenseWidget/   # Widget extension
└── SpendSenseTests/    # Unit tests
```

---

## Contributing & license

Contributions, issues, and suggestions are welcome if this repository is shared with collaborators. Please respect the **privacy-first** goals: avoid introducing silent network uploads of user financial or message content without explicit, informed consent.

Add a **`LICENSE`** file to state how others may use this code; until then, all rights are reserved unless you specify otherwise.

---

## Author

**Yogesh Bhusara** — SpendSense
