import Foundation
import SwiftData
import UIKit

/// Owns the on-device encrypted database.
///
/// Security properties:
/// - The store lives in Application Support/Store with `FileProtectionType.complete`:
///   the file is encrypted with a key derived from the device passcode and is
///   unreadable whenever the phone is locked.
/// - No CloudKit sync (`cloudKitDatabase: .none`) — data never leaves the device
///   unless the user connects an integration.
/// - The container is only created after the user passes Face ID (see RootView),
///   and never while protected data is unavailable.
@MainActor
enum Persistence {
    enum PersistenceError: LocalizedError {
        case deviceLocked
        var errorDescription: String? { "Unlock your iPhone to access your spending data." }
    }

    private static var cached: ModelContainer?

    static var schema: Schema { Schema([Purchase.self, CategoryRule.self]) }

    static func container() throws -> ModelContainer {
        if let cached { return cached }
        guard UIApplication.shared.isProtectedDataAvailable else { throw PersistenceError.deviceLocked }

        let directory = try storeDirectory()
        let config = ModelConfiguration(
            "Purchases",
            schema: schema,
            url: directory.appendingPathComponent("Purchases.store"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        cached = container
        return container
    }

    static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("Store", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        // Re-assert in case the directory pre-existed with a weaker class.
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dir.path)
        return dir
    }

    /// Wipes everything outside the database (call after deleting all models):
    /// pending inbox, all Keychain secrets and preferences.
    static func eraseNonDatabaseData() {
        PurchaseInbox.shared.removeAll()
        KeychainStore.deleteAll()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
