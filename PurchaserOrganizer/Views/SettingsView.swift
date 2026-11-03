import SpendCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var integrations: IntegrationManager
    @Query private var purchases: [Purchase]
    @State private var confirmErase = false
    @State private var message: String?
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Set up automatic Apple Pay capture") { WalletAutomationGuide() }
                    if FinanceKitImporter.isSupported {
                        Button("Import Apple Card & Apple Cash history") {
                            Task {
                                do {
                                    let n = try await FinanceKitImporter(context: context).importRecent()
                                    message = "Imported \(n) transactions."
                                } catch { message = error.localizedDescription }
                            }
                        }
                    }
                } header: { Text("Apple Pay capture") }

                Section {
                    Button("Create CSV export") { makeCSV() }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share CSV", systemImage: "square.and.arrow.up") }
                    }
                } header: { Text("Export") } footer: {
                    Text("The file is created in temporary storage, protected while the phone is locked, and deleted when you lock the app.")
                }

                Section {
                    Button("Lock now") { lock.lock() }
                    NavigationLink("How your data is protected") { SecurityInfoView() }
                    Button("Delete all data", role: .destructive) { confirmErase = true }
                } header: { Text("Privacy & security") }

                if let message { Section { Text(message).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete every purchase, rule and connection from this iPhone?",
                                isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { Task { await eraseAll() } }
            }
            .onDisappear { removeExport() }
        }
    }

    private func makeCSV() {
        removeExport()
        var lines = ["Date,Merchant,Category,Amount,Currency,Card"]
        let df = ISO8601DateFormatter()
        for p in purchases.sorted(by: { $0.date < $1.date }) {
            lines.append([
                df.string(from: p.date), p.merchantName, p.category.displayName,
                "\(p.amount)", p.currencyCode, p.cardName ?? "",
            ].map(SpreadsheetSafety.csvField).joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("purchases-\(UUID().uuidString.prefix(8)).csv")
        do {
            try lines.joined(separator: "\n").data(using: .utf8)!
                .write(to: url, options: [.atomic, .completeFileProtection])
            exportURL = url
        } catch {
            message = error.localizedDescription
        }
    }

    private func removeExport() {
        if let exportURL { try? FileManager.default.removeItem(at: exportURL) }
        exportURL = nil
    }

    private func eraseAll() async {
        do {
            // Revoke tokens with each provider before forgetting them.
            for integration in integrations.integrations where integration.isConnected {
                await integrations.disconnect(integration)
            }
            try context.delete(model: Purchase.self)
            try context.delete(model: CategoryRule.self)
            try context.save()
            Persistence.eraseNonDatabaseData()
            lock.lock()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct WalletAutomationGuide: View {
    var body: some View {
        List {
            Section {
                Text("iOS doesn't let any app read your Apple Pay history directly. The secure, Apple-supported way is a personal Shortcuts automation that runs each time you tap a Wallet card — it works with every card, not just Apple Card.")
                    .font(.subheadline)
            }
            Section("One-time setup (≈1 minute)") {
                step(1, "Open the **Shortcuts** app → **Automation** tab → **+** → **Transaction**.")
                step(2, "Select **all your cards**, keep all categories, tap **Run Immediately**, then **Next**.")
                step(3, "Choose **New Blank Automation** → **Add Action** → search **Log Purchase** (Purchaser Organizer).")
                step(4, "Set **Merchant** → *Shortcut Input › Merchant*, **Amount** → *Shortcut Input › Amount*, **Card or Pass** → *Shortcut Input › Card or Pass*.")
                step(5, "Tap **Done**. Pay with Apple Pay once to test — you'll see a confirmation banner.")
            }
            Section {
                Text("Purchases made while your iPhone is locked are held in an encrypted drop box and imported the next time you open the app.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Apple Pay capture")
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).frame(width: 28, height: 28).background(.tint.opacity(0.15), in: Circle())
            Text(text).font(.subheadline)
        }
    }
}

struct SecurityInfoView: View {
    var body: some View {
        List {
            item("lock.shield", "Encrypted on device", "Your purchases are stored only on this iPhone with iOS Complete Data Protection — unreadable while the phone is locked.")
            item("faceid", "Face ID lock", "The app locks whenever it leaves the screen, and hides its contents from the app switcher.")
            item("icloud.slash", "No cloud, no tracking", "No account, no analytics, no ads, no third-party SDKs. No data is sent anywhere unless you connect a service.")
            item("key.fill", "Keychain-only secrets", "Tokens for connected services live in the Keychain, this-device-only, never synced or backed up to other devices.")
            item("network.badge.shield.half.filled", "Locked-down networking", "HTTPS/TLS 1.2+ only, no caching or cookies, and each connection may only talk to its own service's servers.")
            item("person.badge.key", "Least privilege", "Google access is limited to the single spreadsheet the app creates. Sign-in uses OAuth with PKCE — the app never sees your password.")
        }
        .navigationTitle("Security")
    }

    private func item(_ symbol: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: symbol).foregroundStyle(.tint) }
        .padding(.vertical, 4)
    }
}
