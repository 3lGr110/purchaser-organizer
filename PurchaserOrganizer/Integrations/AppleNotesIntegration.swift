import Foundation

/// Apple Notes has no public API. Instead of asking for any access, the user builds
/// a Shortcut: "Get Spending Summary" → "Append to Note". The app never touches
/// Notes and holds no credentials — the most private option available.
/// The same pattern works for Reminders, Messages, Mail, Files, Calendar, etc.
@MainActor
final class AppleNotesIntegration: SpendIntegration {
    let descriptor = IntegrationDescriptor(
        id: "apple-notes",
        name: "Apple Notes (via Shortcuts)",
        symbolName: "note.text",
        summary: "Append a spending summary to a note — or any app Shortcuts supports.",
        dataShared: "A text summary (totals per category and top merchant) is handed to the Shortcuts app on your iPhone. Nothing is sent to a server by this app.",
        method: .shortcut(instructions: """
        1. Open Shortcuts → Automation → New Automation → Time of Day (e.g. every Sunday).
        2. Add action “Get Spending Summary” (Purchaser Organizer), period: This Week.
        3. Add action “Append to Note” and pick your note.
        4. Turn on “Run Immediately”.
        """)
    )

    var isConnected: Bool { UserDefaults.standard.bool(forKey: SpendingSummaryIntent.optInKey) }

    /// "Connecting" = opting in to let Shortcuts read summaries.
    func connect(credentials: [String: String]) async throws {
        UserDefaults.standard.set(true, forKey: SpendingSummaryIntent.optInKey)
    }

    func disconnect() async {
        UserDefaults.standard.set(false, forKey: SpendingSummaryIntent.optInKey)
    }

    /// Data is pulled by the Shortcut; nothing to push.
    func export(_ records: [ExportRecord]) async throws {}
}
