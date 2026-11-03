# Security model

Goal: a spending tracker that is safe even if the phone is stolen, the network is
hostile, or a connected service is compromised.

## Data at rest
- **On-device only.** SwiftData store with CloudKit disabled. No backend, no account.
- **Complete Data Protection** (`NSFileProtectionComplete`, app-wide entitlement + explicit
  directory attribute). The database is encrypted with a key tied to the device passcode
  and is unreadable whenever the phone is locked.
- **Locked-phone capture without weakening that:** purchases captured while locked are
  written as individual files with `completeUnlessOpen` (write-only while locked;
  readable only after unlock), capped at 500 files, then merged into the main store.
- **Secrets** (Notion token, Google OAuth tokens) live only in the Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, non-synchronizable.
- **Delete all data** revokes OAuth grants, wipes the database, inbox, Keychain and preferences.

## Access
- **Face ID / Touch ID / passcode gate** before any data is loaded. Refuses to run on a
  device with no passcode. Re-locks on background; privacy shield hides the app-switcher snapshot.
- Shortcuts **"Get Spending Summary"** is opt-in and requires the device to be unlocked
  (`IntentAuthenticationPolicy.requiresAuthentication`). **"Log Purchase"** is write-only.

## Data in transit
- One `SecureHTTPClient` for all traffic: HTTPS only, TLS ≥ 1.2, ephemeral session (no
  cache/cookies/credential storage), **per-integration host allowlist**, errors never
  include response bodies.
- App Transport Security has **no exceptions**.
- **OAuth 2.0 + PKCE (S256)** with `state` verification, ephemeral web session, **no client
  secret shipped in the app**, token revocation on disconnect.
- **Least privilege:** Google uses `drive.file` (only the one sheet the app creates);
  Notion internal integrations see only pages the user explicitly shares.

## Input handling
- All external strings (Shortcut input, FinanceKit, manual) are stripped of control
  characters and length-capped (200 chars); amounts are bounded and stored as integer
  hundredths (no floating-point money).
- **CSV / spreadsheet formula injection (CWE-1236)** neutralized for CSV export, and
  Google Sheets writes use `valueInputOption=RAW`.
- Integrations receive a minimal `ExportRecord` (no raw merchant strings, notes or ids).

## Privacy
- No analytics, ads, crash reporters or third-party SDKs. Privacy manifest declares no
  tracking and no collected data. Logs use `OSLog` with private redaction.

## Known limitations / roadmap
- Certificate pinning is not used (Google/Notion rotate certificates; pinning would break
  sync). Revisit with SPKI pinning to intermediate CAs if a backend is added.
- No jailbreak detection (easily bypassed; Data Protection is the real control).
- The SwiftData store is included in *encrypted* iCloud/Finder backups. Set
  `isExcludedFromBackup` on `Application Support/Store` if you want no backups at all.

## Reporting
Please report vulnerabilities privately to the repository owner rather than in public issues.
