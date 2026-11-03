import Foundation

/// A purchase that was captured but not yet written to the database.
struct PendingPurchase: Codable, Identifiable {
    var id: UUID = UUID()
    var merchant: String
    var amount: Decimal
    var currencyCode: String
    var date: Date
    var cardName: String?
    var merchantCategoryCode: Int?
    var source: PurchaseSource
    var externalID: String?
}

/// Write-only drop box used while the iPhone is locked.
///
/// When you pay with Apple Pay from the lock screen, the Wallet "Transaction"
/// automation runs our intent while the device is still locked. The main
/// database is `FileProtectionType.complete` and therefore unreadable — so
/// instead each purchase is written as its own small file with
/// `.completeUnlessOpen`. iOS lets an app *create* such files while locked
/// (using an asymmetric key), but they can only be *read* again after the
/// user unlocks. Nothing already stored is ever exposed while locked.
final class PurchaseInbox {
    static let shared = PurchaseInbox()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Hard cap so a runaway automation can't fill the disk.
    private let maxPendingFiles = 500

    var directory: URL {
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                         appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Inbox", isDirectory: true)
    }

    func enqueue(_ purchase: PendingPurchase) throws {
        try fileManager.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        let existing = (try? fileManager.contentsOfDirectory(atPath: directory.path).count) ?? 0
        guard existing < maxPendingFiles else {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        let data = try encoder.encode(purchase)
        let url = directory.appendingPathComponent("\(purchase.id.uuidString).json")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    /// Returns pending purchases. Only works once the device is unlocked.
    func pending() -> [(url: URL, purchase: PendingPurchase)] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let purchase = try? decoder.decode(PendingPurchase.self, from: data) else {
                    return nil
                }
                return (url, purchase)
            }
    }

    func remove(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
    }
}
