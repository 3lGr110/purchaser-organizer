import Foundation
import SpendCore

/// The minimal, explicit set of fields an integration is allowed to receive.
/// Integrations never see raw merchant strings, notes, card numbers or ids of other rows.
struct ExportRecord: Sendable {
    let id: UUID
    let date: Date
    let merchant: String
    let category: SpendCategory
    let amount: Decimal
    let currencyCode: String
    let card: String?

    init(_ purchase: Purchase) {
        id = purchase.id
        date = purchase.date
        merchant = purchase.merchantName
        category = purchase.category
        amount = purchase.amount
        currencyCode = purchase.currencyCode
        card = purchase.cardName
    }
}

struct CredentialField: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let placeholder: String
    let isSecret: Bool
}

enum ConnectionMethod {
    /// Sign in with the provider in a secure browser sheet (OAuth + PKCE).
    case oauth
    /// The user pastes a token / id (stored only in the Keychain).
    case credentials([CredentialField])
    /// Works through Apple Shortcuts; the app holds no credentials at all.
    case shortcut(instructions: String)
}

struct IntegrationDescriptor: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let summary: String
    /// Shown to the user before connecting — plain-language data disclosure.
    let dataShared: String
    let method: ConnectionMethod
}

/// Implement this to add a new connection (Notion, Google, Notes, YNAB, Airtable, …).
/// Then add one line to `IntegrationRegistry.all`. Remove that line to remove it.
@MainActor
protocol SpendIntegration: AnyObject {
    var descriptor: IntegrationDescriptor { get }
    var isConnected: Bool { get }

    /// For `.credentials` and `.shortcut` methods.
    func connect(credentials: [String: String]) async throws
    /// For `.oauth`.
    func connectWithOAuth() async throws
    /// Must delete every secret the integration stored, and revoke tokens if possible.
    func disconnect() async
    /// Push purchases out. Called only with records the user hasn't exported to this integration yet.
    func export(_ records: [ExportRecord]) async throws
}

extension SpendIntegration {
    func connect(credentials: [String: String]) async throws { throw IntegrationError.unsupported }
    func connectWithOAuth() async throws { throw IntegrationError.unsupported }
}

enum IntegrationError: LocalizedError {
    case unsupported, invalidCredentials(String), notConnected
    var errorDescription: String? {
        switch self {
        case .unsupported: return "This connection method isn't supported."
        case .invalidCredentials(let why): return why
        case .notConnected: return "Connect this integration first."
        }
    }
}
