import Charts
import SpendCore
import SwiftUI

/// Drill-down for one category — e.g. Groceries → which supermarkets and how much at each.
struct CategoryDetailView: View {
    let category: SpendCategory
    let records: [SpendRecord]
    private let analyzer = SpendingAnalyzer()

    private var scoped: [SpendRecord] { records.filter { $0.category == category } }

    var body: some View {
        let merchants = analyzer.topMerchants(scoped, limit: 12)
        let monthly = analyzer.totals(scoped, by: .month, count: 6)
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average per month").font(.subheadline).foregroundStyle(.secondary)
                    Text(Money.format(analyzer.averageMonthly(records, category: category)))
                        .font(.title.bold())
                }
                Chart(monthly) { item in
                    LineMark(x: .value("Month", item.start, unit: .month), y: .value("Spent", item.total.double))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Month", item.start, unit: .month), y: .value("Spent", item.total.double))
                        .foregroundStyle(category.color.opacity(0.2).gradient)
                        .interpolationMethod(.catmullRom)
                }
                .foregroundStyle(category.color)
                .frame(height: 160)
            }

            Section("Where you spend") {
                if merchants.isEmpty {
                    Text("No purchases yet.").foregroundStyle(.secondary)
                } else {
                    Chart(merchants) { m in
                        BarMark(x: .value("Spent", m.total.double), y: .value("Merchant", m.merchant))
                            .foregroundStyle(category.color.gradient)
                            .annotation(position: .trailing) {
                                Text(Money.format(m.total)).font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(max(merchants.count, 1)) * 34)

                    ForEach(merchants) { m in
                        HStack {
                            Text(m.merchant)
                            Spacer()
                            Text("\(m.count) visits").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.displayName)
    }
}
