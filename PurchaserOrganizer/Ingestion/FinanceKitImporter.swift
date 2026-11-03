import Foundation
import SwiftData

#if canImport(FinanceKit) && FINANCEKIT_ENABLED
import FinanceKit

/// Imports Apple Card / Apple Cash / Apple Savings transactions directly from Wallet.
///
/// FinanceKit requires the `com.apple.developer.financekit` entitlement, which Apple
/// grants on request (https://developer.apple.com/financekit/). Until you have it,
/// leave the `FINANCEKIT_ENABLED` compilation flag off — the Wallet automation path
/// works for every card without it.
@MainActor
struct FinanceKitImporter {
    let context: ModelContext

    static var isSupported: Bool { FinanceStore.isDataAvailable(.financialData) }

    func importRecent(limit: Int = 500) async throws -> Int {
        let store = FinanceStore.shared
        let status = try await store.requestAuthorization()
        guard status == .authorized else { return 0 }

        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\Transaction.transactionDate, order: .reverse)],
            predicate: nil,
            limit: limit,
            offset: nil
        )
        let transactions = try await store.transactions(query: query)
        let ingestor = PurchaseIngestor(context: context)
        let categorizer = ingestor.categorizer()
        var imported = 0
        for tx in transactions {
            let sign: Decimal = tx.creditDebitIndicator == .debit ? 1 : -1
            let pending = PendingPurchase(
                merchant: tx.merchantName ?? tx.transactionDescription,
                amount: tx.transactionAmount.amount * sign,
                currencyCode: tx.transactionAmount.currencyCode,
                date: tx.transactionDate,
                cardName: "Apple Card / Cash",
                merchantCategoryCode: tx.merchantCategoryCode.map { Int($0.rawValue) },
                source: .financeKit,
                externalID: tx.id.uuidString
            )
            if (try? ingestor.insert(pending, using: categorizer)) == true { imported += 1 }
        }
        try context.save()
        return imported
    }
}
#else
@MainActor
struct FinanceKitImporter {
    let context: ModelContext
    static var isSupported: Bool { false }
    func importRecent(limit: Int = 500) async throws -> Int { 0 }
}
#endif
