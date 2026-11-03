import Foundation
import SwiftData

/// The single list of available connections.
/// ➕ To add one: write a `SpendIntegration` and append it here.
/// ➖ To remove one: delete its line (and its file).
@MainActor
enum IntegrationRegistry {
    static func all() -> [any SpendIntegration] {
        [
            NotionIntegration(),
            GoogleSheetsIntegration(),
            AppleNotesIntegration(),
        ]
    }
}

/// Keeps track of what was exported where and runs syncs.
@MainActor
final class IntegrationManager: ObservableObject {
    @Published private(set) var integrations: [any SpendIntegration]
    @Published var statusMessage: String?
    @Published private(set) var syncingID: String?

    private let defaults = UserDefaults.standard

    init(integrations: [any SpendIntegration] = IntegrationRegistry.all()) {
        self.integrations = integrations
    }

    func refresh() { objectWillChange.send() }

    func lastSync(_ id: String) -> Date? {
        defaults.object(forKey: "integration.\(id).cursor") as? Date
    }

    private func setLastSync(_ id: String, _ date: Date?) {
        defaults.set(date, forKey: "integration.\(id).cursor")
    }

    /// Exports purchases added since the last successful sync of that integration.
    func sync(_ integration: any SpendIntegration, context: ModelContext) async {
        let id = integration.descriptor.id
        guard integration.isConnected else { statusMessage = IntegrationError.notConnected.localizedDescription; return }
        syncingID = id
        defer { syncingID = nil }

        let cursor = lastSync(id) ?? .distantPast
        do {
            let purchases = try context.fetch(FetchDescriptor<Purchase>(
                predicate: #Predicate { $0.createdAt > cursor },
                sortBy: [SortDescriptor(\.createdAt)]
            ))
            guard !purchases.isEmpty else { statusMessage = "Already up to date."; return }
            let newest = purchases.map(\.createdAt).max() ?? Date()
            try await integration.export(purchases.map(ExportRecord.init))
            setLastSync(id, newest)
            statusMessage = "Sent \(purchases.count) purchases to \(integration.descriptor.name)."
            Log.sync.info("Synced \(purchases.count, privacy: .public) records to \(id, privacy: .public)")
        } catch {
            statusMessage = error.localizedDescription
            Log.sync.error("Sync to \(id, privacy: .public) failed")
        }
    }

    func disconnect(_ integration: any SpendIntegration) async {
        await integration.disconnect()
        setLastSync(integration.descriptor.id, nil)
        refresh()
    }
}
