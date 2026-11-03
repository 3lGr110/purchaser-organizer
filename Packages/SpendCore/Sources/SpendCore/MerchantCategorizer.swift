import Foundation

/// Where a categorization decision came from, in priority order.
public enum CategorizationSource: String, Codable, Sendable {
    case userRule      // the user corrected this merchant before
    case brandCatalog  // matched a known brand
    case merchantCode  // ISO 18245 MCC from the card network
    case keyword       // generic word such as "market" or "pizza"
    case fallback      // nothing matched
}

public struct CategorizationResult: Sendable, Equatable {
    public let category: SpendCategory
    /// Pretty merchant name, e.g. "Trader Joe's" — answers "which supermarket?".
    public let merchantName: String
    /// Normalized key used for user rules.
    public let merchantKey: String
    /// Canonical brand when known.
    public let brand: String?
    public let source: CategorizationSource
    /// 0...1 rough confidence, used to flag items for review.
    public let confidence: Double
}

/// Decides which category a purchase belongs to.
///
/// Priority: user rule > brand catalog > merchant category code > keyword > other.
public struct MerchantCategorizer: Sendable {
    /// merchantKey -> category, learned when the user recategorizes something.
    public var userRules: [String: SpendCategory]
    private let brands: [MerchantBrand]
    private let keywordHints: [(keyword: String, category: SpendCategory)]

    public init(
        userRules: [String: SpendCategory] = [:],
        brands: [MerchantBrand] = MerchantCatalog.brands,
        keywordHints: [(keyword: String, category: SpendCategory)] = MerchantCatalog.keywordHints
    ) {
        self.userRules = userRules
        self.brands = brands
        self.keywordHints = keywordHints
    }

    public func categorize(merchant raw: String, merchantCategoryCode mcc: Int? = nil) -> CategorizationResult {
        let key = MerchantNormalizer.matchKey(for: raw)
        let brand = matchBrand(key: key)
        let name = brand?.name ?? MerchantNormalizer.displayName(for: raw)

        if let rule = userRules[key] {
            return .init(category: rule, merchantName: name, merchantKey: key,
                         brand: brand?.name, source: .userRule, confidence: 1.0)
        }
        if let brand {
            return .init(category: brand.category, merchantName: brand.name, merchantKey: key,
                         brand: brand.name, source: .brandCatalog, confidence: 0.95)
        }
        if let mcc, let category = MCCMapper.category(for: mcc) {
            return .init(category: category, merchantName: name, merchantKey: key,
                         brand: nil, source: .merchantCode, confidence: 0.85)
        }
        if let hint = matchKeyword(key: key) {
            return .init(category: hint, merchantName: name, merchantKey: key,
                         brand: nil, source: .keyword, confidence: 0.6)
        }
        return .init(category: .other, merchantName: name, merchantKey: key,
                     brand: nil, source: .fallback, confidence: 0.1)
    }

    /// Longest matching pattern wins, so "uber eats" beats "uber" and
    /// "amazon prime" beats "amazon".
    func matchBrand(key: String) -> MerchantBrand? {
        guard !key.isEmpty else { return nil }
        let padded = " \(key) "
        var best: (brand: MerchantBrand, length: Int)?
        for brand in brands {
            for pattern in brand.patterns where padded.contains(" \(pattern) ") {
                if pattern.count > (best?.length ?? 0) {
                    best = (brand, pattern.count)
                }
            }
        }
        return best?.brand
    }

    func matchKeyword(key: String) -> SpendCategory? {
        let padded = " \(key) "
        return keywordHints.first { padded.contains(" \($0.keyword) ") }?.category
    }
}
