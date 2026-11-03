import Foundation

/// Sends purchases to a Notion database as pages.
///
/// Uses a Notion *internal integration* token pasted by the user (no OAuth client
/// secret needs to live in the app). The token only has access to the pages the
/// user explicitly shares with the integration in Notion.
@MainActor
final class NotionIntegration: SpendIntegration {
    private struct Credentials: Codable {
        let token: String
        let databaseID: String
    }

    private static let keychainAccount = "integration.notion"
    private static let apiVersion = "2022-06-28"
    private let http = SecureHTTPClient(allowedHosts: ["api.notion.com"])

    let descriptor = IntegrationDescriptor(
        id: "notion",
        name: "Notion",
        symbolName: "doc.text.fill",
        summary: "Add each purchase as a row in a Notion database.",
        dataShared: "Date, merchant name, category, amount, currency and card name for each purchase.",
        method: .credentials([
            CredentialField(key: "token", label: "Integration secret", placeholder: "ntn_… or secret_…", isSecret: true),
            CredentialField(key: "databaseID", label: "Database ID", placeholder: "32-character ID from the database URL", isSecret: false),
        ])
    )

    var isConnected: Bool { KeychainStore.data(for: Self.keychainAccount) != nil }

    func connect(credentials: [String: String]) async throws {
        let token = (credentials["token"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let rawID = (credentials["databaseID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.hasPrefix("ntn_") || token.hasPrefix("secret_"), token.count < 200,
              token.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
            throw IntegrationError.invalidCredentials("That doesn't look like a Notion integration secret.")
        }
        let databaseID = rawID.replacingOccurrences(of: "-", with: "").lowercased()
        guard databaseID.count == 32, databaseID.allSatisfy(\.isHexDigit) else {
            throw IntegrationError.invalidCredentials("The database ID should be 32 hexadecimal characters.")
        }

        // Verify access before saving anything.
        var request = baseRequest(path: "/v1/databases/\(databaseID)", token: token)
        request.httpMethod = "GET"
        do { try await http.send(request) } catch {
            throw IntegrationError.invalidCredentials("Notion rejected the connection. Make sure the database is shared with your integration.")
        }
        try KeychainStore.setCodable(Credentials(token: token, databaseID: databaseID), for: Self.keychainAccount)
    }

    func disconnect() async {
        KeychainStore.delete(Self.keychainAccount)
    }

    func export(_ records: [ExportRecord]) async throws {
        guard let creds = KeychainStore.codable(Credentials.self, for: Self.keychainAccount) else {
            throw IntegrationError.notConnected
        }
        let dateFormatter = ISO8601DateFormatter()
        for record in records {
            var request = baseRequest(path: "/v1/pages", token: creds.token)
            request.httpMethod = "POST"
            let body: [String: Any] = [
                "parent": ["database_id": creds.databaseID],
                "properties": [
                    "Name": ["title": [["text": ["content": record.merchant]]]],
                    "Amount": ["number": (record.amount as NSDecimalNumber).doubleValue],
                    "Category": ["select": ["name": record.category.displayName]],
                    "Date": ["date": ["start": dateFormatter.string(from: record.date)]],
                    "Currency": ["select": ["name": record.currencyCode]],
                    "Card": ["rich_text": [["text": ["content": record.card ?? ""]]]],
                ],
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            try await http.send(request)
            // Notion's rate limit is ~3 requests/second.
            try await Task.sleep(nanoseconds: 350_000_000)
        }
    }

    private func baseRequest(path: String, token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.notion.com\(path)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
