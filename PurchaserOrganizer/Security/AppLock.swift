import Foundation
import LocalAuthentication
import SwiftUI

/// Face ID / Touch ID / passcode gate for the whole app.
///
/// No purchase data is loaded into memory until `isUnlocked` becomes true, and
/// the app re-locks every time it goes to the background.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var lastError: String?
    private var isAuthenticating = false

    func unlock() async {
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        // `.deviceOwnerAuthentication` = biometrics with device-passcode fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on the device: refuse to show financial data.
            lastError = "Set a device passcode in Settings to protect your spending data."
            return
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your spending data"
            )
            isUnlocked = ok
            lastError = nil
        } catch {
            lastError = "Authentication failed. Try again."
        }
    }

    func lock() {
        isUnlocked = false
    }
}
