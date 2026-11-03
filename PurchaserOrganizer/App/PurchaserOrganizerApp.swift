import SwiftUI

@main
struct PurchaserOrganizerApp: App {
    @StateObject private var lock = AppLock()
    @StateObject private var integrations = IntegrationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(lock)
                .environmentObject(integrations)
        }
    }
}
