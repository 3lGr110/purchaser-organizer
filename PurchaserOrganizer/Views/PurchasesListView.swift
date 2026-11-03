import SpendCore
import SwiftData
import SwiftUI

struct PurchasesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @State private var search = ""
    @State private var categoryFilter: SpendCategory?
    @State private var showingAdd = false

    private var filtered: [Purchase] {
        purchases.filter { p in
            (categoryFilter == nil || p.category == categoryFilter) &&
            (search.isEmpty || p.merchantName.localizedCaseInsensitiveContains(search))
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [Purchase]
        var id: Date { day }
    }

    private var grouped: [DayGroup] {
        let cal = Calendar.current
        return Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped) { group in
                    Section(group.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.items) { purchase in
                            NavigationLink { EditPurchaseView(purchase: purchase) } label: {
                                PurchaseRow(purchase: purchase)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(group.items[index]) }
                            try? context.save()
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("No purchases", systemImage: "creditcard",
                                           description: Text("Apple Pay purchases appear here automatically."))
                }
            }
            .searchable(text: $search, prompt: "Search merchants")
            .navigationTitle("Purchases")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All categories") { categoryFilter = nil }
                        ForEach(SpendCategory.allCases) { c in
                            Button { categoryFilter = c } label: { Label(c.displayName, systemImage: c.symbolName) }
                        }
                    } label: {
                        Image(systemName: categoryFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddPurchaseView() }
        }
    }
}

struct PurchaseRow: View {
    let purchase: Purchase
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: purchase.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(purchase.merchantName).font(.body.weight(.medium))
                    if purchase.needsReview {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).font(.caption)
                            .accessibilityLabel("Category may need review")
                    }
                }
                Text([purchase.category.displayName, purchase.cardName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.format(purchase.amount, purchase.currencyCode))
                .font(.body.monospacedDigit())
                .foregroundStyle(purchase.amount < 0 ? .green : .primary)
        }
    }
}

struct EditPurchaseView: View {
    @Environment(\.modelContext) private var context
    @Bindable var purchase: Purchase
    @State private var rememberForMerchant = true

    var body: some View {
        Form {
            Section("Purchase") {
                LabeledContent("Merchant", value: purchase.merchantName)
                LabeledContent("Amount", value: Money.format(purchase.amount, purchase.currencyCode))
                LabeledContent("Date", value: purchase.date.formatted(date: .abbreviated, time: .shortened))
                if let card = purchase.cardName { LabeledContent("Card", value: card) }
                LabeledContent("Captured from", value: sourceLabel)
            }
            Section {
                Picker("Category", selection: Binding(
                    get: { purchase.category },
                    set: { PurchaseIngestor(context: context).recategorize(purchase, as: $0, rememberForMerchant: rememberForMerchant) }
                )) {
                    ForEach(SpendCategory.allCases) { c in
                        Label(c.displayName, systemImage: c.symbolName).tag(c)
                    }
                }
                Toggle("Always use for \(purchase.merchantName)", isOn: $rememberForMerchant)
            } header: {
                Text("Category")
            } footer: {
                Text("Detected via \(sourceExplanation). Corrections are remembered on this device only.")
            }
            Section("Note") {
                TextField("Optional note", text: Binding(
                    get: { purchase.note ?? "" },
                    set: { purchase.note = String($0.prefix(500)) }
                ), axis: .vertical)
            }
            Section("Original merchant text") {
                Text(purchase.rawMerchant).font(.footnote.monospaced()).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(purchase.merchantName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    private var sourceLabel: String {
        switch purchase.source {
        case .walletAutomation: return "Apple Pay (Wallet automation)"
        case .financeKit: return "Apple Card / Cash"
        case .manual: return "Manual entry"
        }
    }

    private var sourceExplanation: String {
        switch purchase.categorySource {
        case .userRule: return "your rule"
        case .brandCatalog: return "known brand"
        case .merchantCode: return "card network merchant code"
        case .keyword: return "keyword match"
        case .fallback: return "no match — please review"
        }
    }
}

struct AddPurchaseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var amount: Decimal?
    @State private var date = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Merchant (e.g. Kroger)", text: $merchant)
                    .textInputAutocapitalization(.words)
                TextField("Amount", value: $amount, format: .currency(code: Money.defaultCurrency))
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, in: ...Date())
                if !merchant.isEmpty {
                    let preview = MerchantCategorizer().categorize(merchant: merchant)
                    LabeledContent("Category", value: preview.category.displayName)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Add Purchase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(merchant.isEmpty || amount == nil)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        do {
            try PurchaseIngestor(context: context).insert(PendingPurchase(
                merchant: merchant, amount: amount, currencyCode: Money.defaultCurrency,
                date: date, cardName: nil, merchantCategoryCode: nil, source: .manual
            ))
            try context.save()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
