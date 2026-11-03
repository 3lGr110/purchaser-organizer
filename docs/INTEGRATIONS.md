# Connections

## Adding or removing a connection

1. Create `PurchaserOrganizer/Integrations/MyServiceIntegration.swift` implementing
   `SpendIntegration` (descriptor, `isConnected`, `connect…`, `disconnect`, `export`).
2. Use `SecureHTTPClient(allowedHosts: ["api.myservice.com"])` — only the hosts you list are reachable.
3. Store secrets only via `KeychainStore`.
4. Add one line to `IntegrationRegistry.all()`.

To remove a connection, delete its line from the registry and its file.

## Notion
1. https://www.notion.so/profile/integrations → **New integration** (Internal) → copy the secret.
2. Create a database with these properties:
   | Name | Type |
   |---|---|
   | Name | Title |
   | Amount | Number |
   | Category | Select |
   | Date | Date |
   | Currency | Select |
   | Card | Text |
3. In the database: **••• → Connections → add your integration**.
4. Copy the database ID (the 32 characters in its URL) and paste both into the app.

## Google Sheets
1. Google Cloud Console → create a project → enable **Google Sheets API**.
2. **OAuth consent screen**: add scope `.../auth/drive.file` only.
3. **Credentials → Create OAuth client ID → iOS**, bundle id = your app's bundle id.
4. Put the client ID in `Config/Local.xcconfig` (`GOOGLE_OAUTH_CLIENT_ID = …`).
5. In the app: Connections → Google Sheets → Sign in. A sheet named *Purchaser Organizer* is created.

## Apple Notes (and Reminders, Messages, Mail…)
Notes has no API, so the app exposes a **Get Spending Summary** Shortcuts action.
Build a Shortcut: *Get Spending Summary* → *Append to Note*. Enable it in
Connections → Apple Notes. The app itself never accesses Notes.

## Ideas for next connections
YNAB, Airtable, Todoist, Microsoft Excel/OneDrive (Graph API with PKCE), Splitwise, Slack webhook digest.
