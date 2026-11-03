import Foundation

/// Cleans up the raw merchant strings that card networks, Wallet and Shortcuts
/// hand us ("SQ *BLUE BOTTLE #123 OAKLAND CA", "TST* JOES PIZZA 0042") into
/// something stable we can match on and something pretty we can show.
public enum MerchantNormalizer {

    /// Payment-processor prefixes that hide the real merchant name.
    static let processorPrefixes: [String] = [
        "sq *", "sq*", "tst* ", "tst*", "sp * ", "sp *", "sp*", "paypal *", "paypal*",
        "pp*", "apl*", "apl* ", "dd *", "dd*", "ddc*", "sumup *", "sumup*",
        "zettle_*", "iz *", "iz*", "py *", "pos ", "purchase ", "debit card purchase ",
        "checkcard ", "pos debit "
    ]

    /// Hard upper bound on input size. Anything longer is truncated before
    /// processing so a malicious Shortcut input can't make us do huge work.
    public static let maxInputLength = 200

    /// Removes control characters and caps length. Use on every external string.
    public static func sanitize(_ raw: String) -> String {
        let scalars = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        var cleaned = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > maxInputLength {
            cleaned = String(cleaned.prefix(maxInputLength))
        }
        return cleaned
    }

    /// A lowercase, punctuation-free key used for matching and for user rules.
    /// "McDonald's #4521" -> "mcdonalds"
    public static func matchKey(for raw: String) -> String {
        var s = sanitize(raw).lowercased()
        s = s.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))

        for prefix in processorPrefixes where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
            break
        }

        // Drop apostrophes so "mcdonald's" == "mcdonalds".
        s = s.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")

        // Everything after a "*" is usually an order/reference id ("amzn mktp us*2k4").
        if let star = s.firstIndex(of: "*") {
            let head = s[..<star]
            if head.trimmingCharacters(in: .whitespaces).count >= 3 {
                s = String(head)
            }
        }

        // Keep letters, digits and spaces only.
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        s = String(String.UnicodeScalarView(s.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))

        var tokens = s.split(separator: " ").map(String.init)

        // Drop store numbers and other trailing numeric noise, e.g. "4521", "000123".
        tokens = tokens.filter { token in
            !(token.allSatisfy(\.isNumber) && tokens.count > 1)
        }
        // Drop a trailing two-letter US state code ("... oakland ca").
        if tokens.count > 2, let last = tokens.last, last.count == 2, usStateCodes.contains(last) {
            tokens.removeLast()
        }
        return tokens.joined(separator: " ")
    }

    /// A human-friendly display name. Prefers the catalog brand name if known.
    public static func displayName(for raw: String) -> String {
        let key = matchKey(for: raw)
        guard !key.isEmpty else { return "Unknown merchant" }
        return key.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static let usStateCodes: Set<String> = [
        "al","ak","az","ar","ca","co","ct","de","fl","ga","hi","id","il","in","ia","ks","ky","la",
        "me","md","ma","mi","mn","ms","mo","mt","ne","nv","nh","nj","nm","ny","nc","nd","oh","ok",
        "or","pa","ri","sc","sd","tn","tx","ut","vt","va","wa","wv","wi","wy","dc","pr"
    ]
}
