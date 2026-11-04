# Purchaser Organizer

A private, on-device iPhone app (iPhone 14 and newer, iOS 17+) that captures every
Apple Pay purchase, figures out **what kind of place** it was (supermarket, fast food,
gas…), **which one** (Kroger vs. Aldi vs. Trader Joe's), and **how much** — then shows
it in charts and can send it to Notion, Google Sheets, Apple Notes and more.

## How purchases get in

| Path | Covers | Needs |
|---|---|---|
| **Wallet "Transaction" automation** → `Log Purchase` intent | Every card in Apple Wallet | One-time Shortcuts setup (in-app guide, [docs](docs/WALLET_AUTOMATION.md)) |
| **FinanceKit import** | Apple Card, Apple Cash, Savings (incl. merchant category codes) | Entitlement from Apple ([request](https://developer.apple.com/financekit/)) |
| **Manual entry** | Cash, anything else | — |

> iOS does not allow any third-party app to silently read Apple Pay history. The
> Shortcuts Transaction automation is Apple's supported, privacy-preserving hook, and
> it fires right after each tap — even from the lock screen.

## How categorization works (`Packages/SpendCore`)

1. **Your corrections** — recategorize once, and that merchant is remembered.
2. **Brand catalog** — ~180 known chains (Walmart, Kroger, H-E-B, McDonald's, Chick-fil-A, Shell, Netflix…). Longest match wins, so *Uber Eats* ≠ *Uber*.
3. **Merchant Category Code** (from FinanceKit) — e.g. 5411 = grocery, 5814 = fast food.
4. **Keywords** — "supermarket", "taqueria", "pizza", "pharmacy"…
5. Otherwise **Other**, flagged ⚠️ for review.

Merchant strings are normalized first (`SQ *BLUE BOTTLE #123 OAKLAND CA` → `Blue Bottle`).

## Screens

- **Overview** – total for week/month/year, category donut, trend bars, monthly average, recurring charges.
- **Category drill-down** – e.g. *Groceries*: which supermarkets, how much at each, 6-month trend.
- **Purchases** – searchable, filterable list; tap to recategorize.
- **Connections** – plug-in integrations (add/remove in one line, see [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md)).
- **Settings** – Apple Pay setup guide, CSV export, lock, delete-all.

## Security

See [SECURITY.md](SECURITY.md). Highlights: on-device only, Complete Data Protection,
Face ID gate, Keychain (this-device-only) secrets, OAuth + PKCE, host-allowlisted
TLS-only networking, spreadsheet-formula-injection defense, no third-party SDKs.

## Build & run (needs a Mac)

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # optional: Google client ID
xcodegen generate
open PurchaserOrganizer.xcodeproj
```

Select your Team under *Signing & Capabilities*, change the bundle id prefix in
`project.yml`, plug in your iPhone and Run.

Run the core logic tests (macOS or Linux with Swift 5.9+):

```bash
cd Packages/SpendCore && swift test
```

## Layout

```
Packages/SpendCore/         Pure-Swift brain: normalizer, catalog, categorizer, analytics (+ tests)
PurchaserOrganizer/
  App/                      App entry, Face ID gate, tabs
  Models/                   SwiftData models, encrypted persistence
  Ingestion/                Locked-phone inbox, ingest/dedupe, FinanceKit importer
  Intents/                  Shortcuts actions: Log Purchase, Get Spending Summary
  Integrations/             Plug-in connections: Notion, Google Sheets, Apple Notes
  Security/                 Keychain, OAuth PKCE, hardened HTTP client, app lock, logging
  Views/                    SwiftUI + Swift Charts
docs/                       Setup guides
```

## Continuous integration

`.github/workflows/ios.yml` runs on every push:
- **SpendCore tests** on Linux and macOS.
- **iOS app build** on a GitHub-hosted Mac (XcodeGen → `xcodebuild` for the iOS Simulator,
  unsigned). The full log is attached to each run as the `xcodebuild-log` artifact.

No Mac needed to know whether the app compiles — check the **Actions** tab.
