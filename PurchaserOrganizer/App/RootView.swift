import SwiftData
import SwiftUI

/// Gatekeeper: nothing below this view touches purchase data until the user
/// authenticates, and the UI is hidden from the app switcher snapshot.
struct RootView: View {
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @State private var container: ModelContainer?
    @State private var loadError: String?
    /// Only auto-prompt after a real trip to the background. (The Face ID sheet itself
    /// toggles scenePhase inactive→active, which would otherwise re-prompt forever on cancel.)
    @State private var returnedFromBackground = false

    var body: some View {
        ZStack {
            if lock.isUnlocked, let container {
                MainTabView()
                    .modelContainer(container)
            } else {
                LockScreenView(errorMessage: loadError ?? lock.lastError) {
                    Task { await unlock() }
                }
            }

            // Privacy screen: covers content in the multitasking switcher.
            if scenePhase != .active && lock.isUnlocked {
                PrivacyShield()
            }
        }
        .task { await unlock() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lock.lock()
                container = nil
                returnedFromBackground = true
            case .active:
                if returnedFromBackground && !lock.isUnlocked {
                    returnedFromBackground = false
                    Task { await unlock() }
                }
            default:
                break
            }
        }
    }

    @MainActor
    private func unlock() async {
        await lock.unlock()
        guard lock.isUnlocked else { return }
        do {
            let container = try Persistence.container()
            PurchaseIngestor(context: container.mainContext).drainInbox()
            self.container = container
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            lock.lock()
        }
    }
}

struct LockScreenView: View {
    let errorMessage: String?
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Purchaser Organizer")
                .font(.title.bold())
            Text("Your spending data is encrypted on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onUnlock) {
                Label("Unlock", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }
}

struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }
            PurchasesListView()
                .tabItem { Label("Purchases", systemImage: "list.bullet.rectangle") }
            IntegrationsView()
                .tabItem { Label("Connections", systemImage: "link") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
