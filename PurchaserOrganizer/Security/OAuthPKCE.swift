import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// OAuth 2.0 Authorization Code flow with PKCE (RFC 7636) for native apps (RFC 8252).
///
/// - No client secret is shipped in the app (secrets in apps are always extractable).
/// - `state` is verified to stop CSRF / authorization-code injection.
/// - Uses an *ephemeral* ASWebAuthenticationSession, so no browser cookies are shared
///   with Safari and the user's Google session isn't left signed in inside our flow.
struct OAuthConfiguration {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let clientID: String
    let redirectURI: String
    let scopes: [String]
    var extraAuthParameters: [String: String] = [:]

    var callbackScheme: String { String(redirectURI.prefix { $0 != ":" }) }
}

struct OAuthTokens: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

enum OAuthError: LocalizedError {
    case notConfigured, cancelled, stateMismatch, missingCode, tokenExchangeFailed
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "This integration has no OAuth client ID configured. See docs/INTEGRATIONS.md."
        case .cancelled: return "Sign-in was cancelled."
        case .stateMismatch: return "Sign-in response failed a security check and was rejected."
        case .missingCode: return "Sign-in did not return an authorization code."
        case .tokenExchangeFailed: return "Could not complete sign-in."
        }
    }
}

@MainActor
final class OAuthClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let config: OAuthConfiguration
    private let http: SecureHTTPClient

    init(config: OAuthConfiguration, http: SecureHTTPClient) {
        self.config = config
        self.http = http
    }

    func authorize() async throws -> OAuthTokens {
        guard !config.clientID.isEmpty, !config.clientID.hasPrefix("$(") else { throw OAuthError.notConfigured }

        let verifier = Self.randomURLSafeString(byteCount: 64)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafeString(byteCount: 32)

        var components = URLComponents(url: config.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        items += config.extraAuthParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = items

        let callback = try await startSession(url: components.url!)
        let returned = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard returned.first(where: { $0.name == "state" })?.value == state else { throw OAuthError.stateMismatch }
        guard let code = returned.first(where: { $0.name == "code" })?.value else { throw OAuthError.missingCode }

        return try await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "code_verifier": verifier,
        ], previousRefreshToken: nil)
    }

    func refresh(_ tokens: OAuthTokens) async throws -> OAuthTokens {
        guard let refreshToken = tokens.refreshToken else { throw OAuthError.tokenExchangeFailed }
        return try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID,
        ], previousRefreshToken: refreshToken)
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }

    private func tokenRequest(_ form: [String: String], previousRefreshToken: String?) async throws -> OAuthTokens {
        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode(form)
        do {
            let response = try await http.sendJSON(request, as: TokenResponse.self)
            return OAuthTokens(
                accessToken: response.access_token,
                refreshToken: response.refresh_token ?? previousRefreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
            )
        } catch {
            throw OAuthError.tokenExchangeFailed
        }
    }

    private func startSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: config.callbackScheme) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? OAuthError.missingCode)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() { continuation.resume(throwing: OAuthError.cancelled) }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }

    // MARK: Helpers

    static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "Secure random generator failed")
        return base64URL(Data(bytes))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func formEncode(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}
