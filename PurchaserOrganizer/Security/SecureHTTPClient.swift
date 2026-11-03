import Foundation

/// The only door through which the app talks to the internet.
///
/// - HTTPS only, TLS 1.2+ (App Transport Security has no exceptions in Info.plist).
/// - Ephemeral session: no disk cache, no cookies, no credential storage.
/// - Host allowlist: a request to any host not explicitly allowed is refused,
///   so a compromised/buggy integration can't exfiltrate data elsewhere.
/// - Errors never include response bodies, so tokens/PII don't end up in logs.
final class SecureHTTPClient {
    enum HTTPError: LocalizedError {
        case hostNotAllowed(String)
        case insecureScheme
        case status(Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .hostNotAllowed(let host): return "Blocked request to non-allowlisted host \(host)."
            case .insecureScheme: return "Only HTTPS connections are allowed."
            case .status(let code): return "The service responded with HTTP \(code)."
            case .invalidResponse: return "The service returned an invalid response."
            }
        }
    }

    private let allowedHosts: Set<String>
    private let session: URLSession

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    @discardableResult
    func send(_ request: URLRequest) async throws -> Data {
        guard let url = request.url, url.scheme?.lowercased() == "https" else {
            throw HTTPError.insecureScheme
        }
        guard let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            throw HTTPError.hostNotAllowed(request.url?.host ?? "?")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HTTPError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw HTTPError.status(http.statusCode) }
        return data
    }

    func sendJSON<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await send(request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
