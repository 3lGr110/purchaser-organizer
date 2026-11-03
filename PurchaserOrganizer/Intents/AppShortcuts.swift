import AppIntents

struct PurchaserShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogPurchaseIntent(),
            phrases: ["Log a purchase in \(.applicationName)"],
            shortTitle: "Log Purchase",
            systemImageName: "creditcard"
        )
        AppShortcut(
            intent: SpendingSummaryIntent(),
            phrases: ["How much did I spend in \(.applicationName)",
                      "Spending summary in \(.applicationName)"],
            shortTitle: "Spending Summary",
            systemImageName: "chart.pie"
        )
    }
}
