import AppIntents
import Foundation
import SpendCore
import UIKit

/// Receives a purchase from the Shortcuts **Wallet → Transaction** automation.
///
/// iOS does not let third-party apps read Apple Pay history directly (only
/// FinanceKit, for Apple Card/Cash). The supported, privacy-preserving way to
/// capture *every* Apple Pay tap is a personal automation the user creates:
///   When I tap any Wallet card → Log Purchase (Merchant, Amount, Card).
/// See docs/WALLET_AUTOMATION.md.
struct LogPurchaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Purchase"
    static var description = IntentDescription(
        "Saves an Apple Pay purchase and sorts it into a spending category.",
        categoryName: "Purchases"
    )
    /// Must keep working from the lock screen right after paying.
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Merchant", requestValueDialog: "Where did you buy it?")
    var merchant: String

    @Parameter(title: "Amount", requestValueDialog: "How much was it?")
    var amount: Double

    @Parameter(title: "Currency Code", description: "ISO code such as USD. Defaults to your region's currency.")
    var currencyCode: String?

    @Parameter(title: "Card or Pass", description: "The Wallet card name, e.g. Apple Card.")
    var card: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)") {
            \.$currencyCode
            \.$card
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount.isFinite else { throw PurchaseIngestor.ValidationError.amountOutOfRange }
        // Round through a string so 12.99 doesn't become 12.989999…
        let decimal = Decimal(string: String(format: "%.2f", amount), locale: Locale(identifier: "en_US_POSIX")) ?? 0
        let pending = PendingPurchase(
            merchant: MerchantNormalizer.sanitize(merchant),
            amount: decimal,
            currencyCode: PurchaseIngestor.validCurrency(currencyCode ?? ""),
            date: Date(),
            cardName: card,
            merchantCategoryCode: nil,
            source: .walletAutomation
        )
        guard !pending.merchant.isEmpty else { throw PurchaseIngestor.ValidationError.missingMerchant }

        // Always land in the encrypted drop box first (works while locked) …
        try PurchaseInbox.shared.enqueue(pending)

        // … then import immediately if the device happens to be unlocked.
        if UIApplication.shared.isProtectedDataAvailable, let container = try? Persistence.container() {
            PurchaseIngestor(context: container.mainContext).drainInbox()
        }

        // Preview category from the built-in catalog only (user rules are locked away).
        let preview = MerchantCategorizer().categorize(merchant: pending.merchant)
        let formatted = pending.amount.formatted(.currency(code: pending.currencyCode))
        return .result(dialog: "Logged \(formatted) at \(preview.merchantName) · \(preview.category.displayName)")
    }
}
