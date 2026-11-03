import AppIntents
import Foundation
import SwiftData
import SpendCore

enum SummaryPeriod: String, AppEnum {
    case week, month, year

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static var caseDisplayRepresentations: [SummaryPeriod: DisplayRepresentation] = [
        .week: "This Week", .month: "This Month", .year: "This Year",
    ]

    var label: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Returns a plain-text spending summary. This is what powers the Apple Notes,
/// Reminders, Messages, Mail… "integrations": a Shortcut can pipe this text into
/// any app ("Append to Note", "Send Message", etc.) without us holding any
/// credentials for those apps.
///
/// Disabled by default; the user opts in under Settings → Shortcuts access.
struct SpendingSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Spending Summary"
    static var description = IntentDescription(
        "Returns a text summary of your spending by category.",
        categoryName: "Reports"
    )
    static var openAppWhenRun = false
    /// The phone must be unlocked (Face ID / passcode) to read data.
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    static let optInKey = "allowShortcutSummaries"

    @Parameter(title: "Period", default: .month)
    var period: SummaryPeriod

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard UserDefaults.standard.bool(forKey: Self.optInKey) else {
            let message = "Spending summaries are turned off. Enable them in Purchaser Organizer → Settings."
            return .result(value: message, dialog: IntentDialog(stringLiteral: message))
        }
        let container = try Persistence.container()
        PurchaseIngestor(context: container.mainContext).drainInbox()
        let text = try SummaryBuilder(context: container.mainContext).summary(for: period)
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

@MainActor
struct SummaryBuilder {
    let context: ModelContext

    func summary(for period: SummaryPeriod, now: Date = Date()) throws -> String {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: period.component, for: now) else { return "" }
        let start = interval.start, end = interval.end
        let purchases = try context.fetch(FetchDescriptor<Purchase>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        ))
        let records = purchases.map(\.spendRecord)
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let currency = purchases.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let fmt: (Decimal) -> String = { $0.formatted(.currency(code: currency)) }

        var lines = ["Spending — \(period.label)",
                     "Total: \(fmt(analyzer.total(records))) across \(records.count) purchases", ""]
        for item in analyzer.totalsByCategory(records) {
            let top = analyzer.topMerchants(records, category: item.category, limit: 1).first?.merchant
            lines.append("• \(item.category.displayName): \(fmt(item.total))" + (top.map { " (mostly \($0))" } ?? ""))
        }
        return lines.joined(separator: "\n")
    }
}
