import Foundation
import SpendCore

/// Appends purchases to a Google Sheet that the app creates in the user's Drive.
///
/// Least privilege: requests only the `drive.file` scope, which grants access
/// *solely to files this app creates* — not the rest of the user's Drive or Gmail.
@MainActor
final class GoogleSheetsIntegration: SpendIntegration {
    private struct State: Codable {
        var tokens: OAuthTokens
        var spreadsheetID: String
    }

    private static let keychainAccount = "integration.google-sheets"
    private let http = SecureHTTPClient(allowedHosts: ["oauth2.googleapis.com", "sheets.googleapis.com", "accounts.google.com"])

    let descriptor = IntegrationDescriptor(
        id: "google-sheets",
        name: "Google Sheets",
        symbolName: "tablecells.fill",
        summary: "Keep a live spreadsheet of every purchase in your Google Drive.",
        dataShared: "Date, merchant name, category, amount, currency and card name. Access is limited to the one spreadsheet this app creates.",
        method: .oauth
    )

    var isConnected: Bool { KeychainStore.data(for: Self.keychainAccount) != nil }

    private lazy var oauth: OAuthClient = {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String ?? ""
        // Google iOS clients use the reversed client ID as the redirect scheme.
        let reversed = clientID.split(separator: ".").reversed().joined(separator: ".")
        return OAuthClient(
            config: OAuthConfiguration(
                authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
                clientID: clientID,
                redirectURI: "\(reversed):/oauth2redirect",
                scopes: ["https://www.googleapis.com/auth/drive.file"]
            ),
            http: http
        )
    }()

    func connectWithOAuth() async throws {
        let tokens = try await oauth.authorize()
        let spreadsheetID = try await createSpreadsheet(accessToken: tokens.accessToken)
        try KeychainStore.setCodable(State(tokens: tokens, spreadsheetID: spreadsheetID), for: Self.keychainAccount)
    }

    func disconnect() async {
        if let state = KeychainStore.codable(State.self, for: Self.keychainAccount) {
            // Best-effort token revocation so the grant disappears from the user's Google account.
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = OAuthClient.formEncode(["token": state.tokens.refreshToken ?? state.tokens.accessToken])
            _ = try? await http.send(request)
        }
        KeychainStore.delete(Self.keychainAccount)
    }

    func export(_ records: [ExportRecord]) async throws {
        guard var state = KeychainStore.codable(State.self, for: Self.keychainAccount) else {
            throw IntegrationError.notConnected
        }
        if state.tokens.isExpired {
            state.tokens = try await oauth.refresh(state.tokens)
            try KeychainStore.setCodable(state, for: Self.keychainAccount)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let rows: [[String]] = records.map { r in
            [
                formatter.string(from: r.date),
                SpreadsheetSafety.neutralize(r.merchant),
                r.category.displayName,
                "\(r.amount)",
                r.currencyCode,
                SpreadsheetSafety.neutralize(r.card ?? ""),
            ]
        }
        let id = state.spreadsheetID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        // valueInputOption=RAW: values are stored as plain text and never parsed as formulas.
        var request = URLRequest(url: URL(string:
            "https://sheets.googleapis.com/v4/spreadsheets/\(id)/values/Purchases!A1:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(state.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["values": rows])
        try await http.send(request)
    }

    private struct CreatedSheet: Decodable { let spreadsheetId: String }

    private func createSpreadsheet(accessToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://sheets.googleapis.com/v4/spreadsheets")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let header = ["Date", "Merchant", "Category", "Amount", "Currency", "Card"]
            .map { ["userEnteredValue": ["stringValue": $0]] }
        let body: [String: Any] = [
            "properties": ["title": "Purchaser Organizer"],
            "sheets": [[
                "properties": ["title": "Purchases"],
                "data": [["startRow": 0, "startColumn": 0, "rowData": [["values": header]]]],
            ]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await http.sendJSON(request, as: CreatedSheet.self).spreadsheetId
    }
}
