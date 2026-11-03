import Foundation
import SwiftData
import SpendCore

/// Turns raw captured purchases into categorized, de-duplicated database rows.
@MainActor
struct PurchaseIngestor {
    let context: ModelContext

    /// Limits enforced on every input regardless of source.
    static let maxAbsoluteAmount: Decimal = 1_000_000
    static let duplicateWindow: TimeInterval = 10 * 60

    func categorizer() -> MerchantCategorizer {
        let rules = (try? context.fetch(FetchDescriptor<CategoryRule>())) ?? []
        return MerchantCategorizer(userRules: Dictionary(
            rules.map { ($0.merchantKey, $0.category) }, uniquingKeysWith: { _, new in new }
        ))
    }

    /// Imports everything waiting in the locked-phone inbox. Returns number imported.
    @discardableResult
    func drainInbox() -> Int {
        let pending = PurchaseInbox.shared.pending()
        guard !pending.isEmpty else { return 0 }
        let categorizer = categorizer()
        var imported = 0
        for item in pending {
            if (try? insert(item.purchase, using: categorizer)) == true { imported += 1 }
            PurchaseInbox.shared.remove(item.url)
        }
        try? context.save()
        Log.ingest.info("Imported \(imported, privacy: .public) purchases from inbox")
        return imported
    }

    /// Validates, categorizes and stores one purchase. Returns false if it was a duplicate.
    @discardableResult
    func insert(_ pending: PendingPurchase, using categorizer: MerchantCategorizer? = nil) throws -> Bool {
        let merchant = MerchantNormalizer.sanitize(pending.merchant)
        guard !merchant.isEmpty else { throw ValidationError.missingMerchant }
        guard abs(pending.amount) <= Self.maxAbsoluteAmount else { throw ValidationError.amountOutOfRange }
        let currency = Self.validCurrency(pending.currencyCode)

        if try isDuplicate(pending, merchant: merchant) { return false }

        let result = (categorizer ?? self.categorizer())
            .categorize(merchant: merchant, merchantCategoryCode: pending.merchantCategoryCode)

        let purchase = Purchase(
            id: pending.id,
            amount: pending.amount,
            currencyCode: currency,
            date: min(pending.date, Date().addingTimeInterval(60)),
            rawMerchant: merchant,
            categorization: result,
            source: pending.source,
            cardName: pending.cardName.map(MerchantNormalizer.sanitize),
            externalID: pending.externalID
        )
        context.insert(purchase)
        return true
    }

    /// The same Apple Card purchase can arrive both from the Wallet automation
    /// and from FinanceKit (with slightly different merchant strings). Two rows from
    /// *different* sources with the same amount within 10 minutes are treated as one.
    /// Rows from the same source are only duplicates if their ids match (two coffees
    /// in a row are two real purchases).
    private func isDuplicate(_ pending: PendingPurchase, merchant: String) throws -> Bool {
        if let externalID = pending.externalID {
            let id: String? = externalID
            var byID = FetchDescriptor<Purchase>(predicate: #Predicate { $0.externalID == id })
            byID.fetchLimit = 1
            if try !context.fetch(byID).isEmpty { return true }
        }
        let pendingID = pending.id
        var byUUID = FetchDescriptor<Purchase>(predicate: #Predicate { $0.id == pendingID })
        byUUID.fetchLimit = 1
        if try !context.fetch(byUUID).isEmpty { return true }

        let hundredths = Purchase.hundredths(from: pending.amount)
        let from = pending.date.addingTimeInterval(-Self.duplicateWindow)
        let to = pending.date.addingTimeInterval(Self.duplicateWindow)
        let key = MerchantNormalizer.matchKey(for: merchant)
        let nearby = try context.fetch(FetchDescriptor<Purchase>(predicate: #Predicate {
            $0.amountHundredths == hundredths && $0.date >= from && $0.date <= to
        }))
        let involvesFinanceKit = { (other: Purchase) in
            other.source == .financeKit || pending.source == .financeKit
        }
        return nearby.contains { other in
            other.source != pending.source && (other.merchantKey == key || involvesFinanceKit(other))
        }
    }

    /// Re-categorizes one purchase and remembers the choice for that merchant.
    func recategorize(_ purchase: Purchase, as category: SpendCategory, rememberForMerchant: Bool) {
        purchase.category = category
        purchase.categorySourceRaw = CategorizationSource.userRule.rawValue
        guard rememberForMerchant, !purchase.merchantKey.isEmpty else { return }

        let key = purchase.merchantKey
        let existing = try? context.fetch(FetchDescriptor<CategoryRule>(predicate: #Predicate { $0.merchantKey == key }))
        if let rule = existing?.first {
            rule.categoryRaw = category.rawValue
        } else {
            context.insert(CategoryRule(merchantKey: key, category: category))
        }
        // Apply the correction to past purchases from the same merchant too.
        let others = (try? context.fetch(FetchDescriptor<Purchase>(predicate: #Predicate { $0.merchantKey == key }))) ?? []
        for other in others { other.category = category }
        try? context.save()
    }

    static func validCurrency(_ code: String) -> String {
        let upper = code.uppercased()
        if upper.count == 3, Locale.commonISOCurrencyCodes.contains(upper) { return upper }
        return Locale.current.currency?.identifier ?? "USD"
    }

    enum ValidationError: LocalizedError {
        case missingMerchant, amountOutOfRange
        var errorDescription: String? {
            switch self {
            case .missingMerchant: return "A merchant name is required."
            case .amountOutOfRange: return "That amount looks wrong."
            }
        }
    }
}
