import Foundation
import SwiftData
import SpendCore

/// How a purchase entered the app.
enum PurchaseSource: String, Codable, CaseIterable {
    case walletAutomation   // Shortcuts "Transaction" automation (any card in Apple Wallet)
    case financeKit         // Apple Card / Apple Cash via FinanceKit
    case manual             // typed in by the user
}

@Model
final class Purchase {
    @Attribute(.unique) var id: UUID
    /// Amount × 100, stored as an integer to avoid floating-point money bugs.
    /// Positive = spend, negative = refund.
    var amountHundredths: Int64
    var currencyCode: String
    var date: Date
    var createdAt: Date

    /// Exactly what the payment network / Shortcut gave us.
    var rawMerchant: String
    /// Cleaned name ("Trader Joe's").
    var merchantName: String
    /// Normalized key, used for learned rules.
    var merchantKey: String
    var brand: String?
    var categoryRaw: String
    var categorySourceRaw: String
    var sourceRaw: String
    /// Card or pass name from Wallet ("Apple Card", "Chase Freedom"). Never the card number.
    var cardName: String?
    var note: String?
    /// FinanceKit transaction id, used to avoid importing twice.
    var externalID: String?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        currencyCode: String,
        date: Date,
        rawMerchant: String,
        categorization: CategorizationResult,
        source: PurchaseSource,
        cardName: String? = nil,
        note: String? = nil,
        externalID: String? = nil
    ) {
        self.id = id
        self.amountHundredths = Purchase.hundredths(from: amount)
        self.currencyCode = currencyCode
        self.date = date
        self.createdAt = Date()
        self.rawMerchant = rawMerchant
        self.merchantName = categorization.merchantName
        self.merchantKey = categorization.merchantKey
        self.brand = categorization.brand
        self.categoryRaw = categorization.category.rawValue
        self.categorySourceRaw = categorization.source.rawValue
        self.sourceRaw = source.rawValue
        self.cardName = cardName
        self.note = note
        self.externalID = externalID
    }

    var amount: Decimal {
        get { Decimal(amountHundredths) / 100 }
        set { amountHundredths = Purchase.hundredths(from: newValue) }
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var categorySource: CategorizationSource {
        CategorizationSource(rawValue: categorySourceRaw) ?? .fallback
    }

    var source: PurchaseSource {
        PurchaseSource(rawValue: sourceRaw) ?? .manual
    }

    var needsReview: Bool {
        categorySource == .fallback || categorySource == .keyword
    }

    var spendRecord: SpendRecord {
        SpendRecord(id: id, date: date, amount: amount, category: category, merchant: merchantName)
    }

    static func hundredths(from amount: Decimal) -> Int64 {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .bankers)
        return (rounded as NSDecimalNumber).int64Value
    }
}

/// A category correction the user made, remembered for every future purchase
/// from the same merchant.
@Model
final class CategoryRule {
    @Attribute(.unique) var merchantKey: String
    var categoryRaw: String
    var createdAt: Date

    init(merchantKey: String, category: SpendCategory) {
        self.merchantKey = merchantKey
        self.categoryRaw = category.rawValue
        self.createdAt = Date()
    }

    var category: SpendCategory { SpendCategory(rawValue: categoryRaw) ?? .other }
}
