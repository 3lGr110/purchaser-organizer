import SwiftData
import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var manager: IntegrationManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(manager.integrations, id: \.descriptor.id) { integration in
                        NavigationLink {
                            IntegrationDetailView(integration: integration)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: integration.descriptor.symbolName)
                                    .frame(width: 32, height: 32)
                                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading) {
                                    Text(integration.descriptor.name).font(.body.weight(.medium))
                                    Text(integration.descriptor.summary).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if integration.isConnected {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        .accessibilityLabel("Connected")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Nothing leaves your iPhone unless you connect a service. Secrets are stored in the iOS Keychain on this device only.")
                }
            }
            .navigationTitle("Connections")
            .onAppear { manager.refresh() }
        }
    }
}

struct IntegrationDetailView: View {
    let integration: any SpendIntegration
    @EnvironmentObject private var manager: IntegrationManager
    @Environment(\.modelContext) private var context
    @State private var fields: [String: String] = [:]
    @State private var working = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("What gets shared") {
                Text(integration.descriptor.dataShared).font(.subheadline)
            }

            if integration.isConnected {
                connectedSection
            } else {
                connectSection
            }

            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            if let status = manager.statusMessage {
                Section { Text(status).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(integration.descriptor.name)
        .disabled(working)
        .overlay { if working { ProgressView() } }
    }

    @ViewBuilder private var connectedSection: some View {
        Section {
            Label("Connected", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            if case .shortcut(let instructions) = integration.descriptor.method {
                Text(instructions).font(.footnote)
            } else {
                Button {
                    run { await manager.sync(integration, context: context) }
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                if let last = manager.lastSync(integration.descriptor.id) {
                    LabeledContent("Last item synced", value: last.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Button("Disconnect", role: .destructive) {
                run { await manager.disconnect(integration) }
            }
        }
    }

    @ViewBuilder private var connectSection: some View {
        switch integration.descriptor.method {
        case .oauth:
            Section {
                Button {
                    run { try await integration.connectWithOAuth() }
                } label: { Label("Sign in with \(integration.descriptor.name)", systemImage: "person.badge.key") }
            } footer: {
                Text("You'll sign in on the provider's own page. This app never sees your password.")
            }
        case .credentials(let credentialFields):
            Section {
                ForEach(credentialFields) { field in
                    let binding = Binding(get: { fields[field.key] ?? "" }, set: { fields[field.key] = $0 })
                    if field.isSecret {
                        SecureField(field.label, text: binding, prompt: Text(field.placeholder))
                            .textContentType(.password)
                    } else {
                        TextField(field.label, text: binding, prompt: Text(field.placeholder))
                    }
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                Button("Connect") {
                    run {
                        try await integration.connect(credentials: fields)
                        fields = [:]
                    }
                }
            } footer: {
                Text("See docs/INTEGRATIONS.md for how to create the token. It's stored only in this device's Keychain.")
            }
        case .shortcut(let instructions):
            Section {
                Text(instructions).font(.footnote)
                Button("Allow Shortcuts to read summaries") {
                    run { try await integration.connect(credentials: [:]) }
                }
            }
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        working = true
        error = nil
        Task {
            do { try await action() } catch { self.error = error.localizedDescription }
            working = false
            manager.refresh()
        }
    }
}
