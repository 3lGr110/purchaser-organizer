import Charts
import SpendCore
import SwiftData
import SwiftUI

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// Trend chart granularity and number of bars.
    var trend: (component: Calendar.Component, count: Int, format: Date.FormatStyle) {
        switch self {
        case .week: return (.day, 7, .dateTime.weekday(.abbreviated))
        case .month: return (.month, 6, .dateTime.month(.abbreviated))
        case .year: return (.year, 3, .dateTime.year())
        }
    }
}

extension Decimal {
    var double: Double { (self as NSDecimalNumber).doubleValue }
}

struct DashboardView: View {
    @Query(sort: \Purchase.date, order: .reverse) private var purchases: [Purchase]
    @State private var period: DashboardPeriod = .month
    @State private var showingAdd = false

    private let analyzer = SpendingAnalyzer()

    private var allRecords: [SpendRecord] { purchases.map(\.spendRecord) }

    private var periodRecords: [SpendRecord] {
        guard let interval = Calendar.current.dateInterval(of: period.component, for: Date()) else { return [] }
        return analyzer.records(allRecords, in: interval)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(DashboardPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if purchases.isEmpty {
                        EmptyStateCard()
                    } else {
                        let records = periodRecords
                        let byCategory = analyzer.totalsByCategory(records)
                        TotalCard(period: period, total: analyzer.total(records), count: records.count,
                                  monthlyAverage: analyzer.averageMonthly(allRecords))
                        CategoryDonutCard(totals: byCategory)
                        TrendCard(period: period, totals: analyzer.totals(
                            allRecords, by: period.trend.component, count: period.trend.count))
                        CategoryListCard(totals: byCategory, records: records, allRecords: allRecords)
                        RecurringCard(charges: analyzer.recurringCharges(allRecords))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add purchase")
            }
            .sheet(isPresented: $showingAdd) { AddPurchaseView() }
        }
    }
}

// MARK: - Cards

private struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline) }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        Card(title: nil) {
            VStack(alignment: .leading, spacing: 8) {
                Label("No purchases yet", systemImage: "creditcard").font(.headline)
                Text("Set up the Wallet automation in Settings → Apple Pay capture so every Apple Pay tap lands here automatically, or tap + to add one.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TotalCard: View {
    let period: DashboardPeriod
    let total: Decimal
    let count: Int
    let monthlyAverage: Decimal

    var body: some View {
        Card(title: nil) {
            Text("Spent this \(period.rawValue.lowercased())").font(.subheadline).foregroundStyle(.secondary)
            Text(Money.format(total)).font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            HStack {
                Label("\(count) purchases", systemImage: "number")
                Spacer()
                Label("Avg \(Money.format(monthlyAverage))/mo", systemImage: "calendar")
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct CategoryDonutCard: View {
    let totals: [CategoryTotal]

    var body: some View {
        Card(title: "Where it went") {
            if totals.isEmpty {
                Text("Nothing spent in this period.").foregroundStyle(.secondary)
            } else {
                Chart(totals) { item in
                    SectorMark(
                        angle: .value("Spent", item.total.double),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(item.category.color)
                    .accessibilityLabel(item.category.displayName)
                    .accessibilityValue(Money.format(item.total))
                }
                .frame(height: 220)
                .chartBackground { _ in
                    if let top = totals.first {
                        VStack {
                            Image(systemName: top.category.symbolName).foregroundStyle(top.category.color)
                            Text(top.category.displayName).font(.caption.bold())
                            Text(top.share.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct TrendCard: View {
    let period: DashboardPeriod
    let totals: [PeriodTotal]

    var body: some View {
        Card(title: "Trend") {
            Chart(totals) { item in
                BarMark(
                    x: .value("Period", item.start, unit: period.trend.component),
                    y: .value("Spent", item.total.double)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: totals.map(\.start)) { _ in
                    AxisValueLabel(format: period.trend.format)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v, format: .currency(code: Money.defaultCurrency).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}

private struct CategoryListCard: View {
    let totals: [CategoryTotal]
    let records: [SpendRecord]
    let allRecords: [SpendRecord]

    var body: some View {
        Card(title: "Categories") {
            ForEach(totals) { item in
                NavigationLink {
                    CategoryDetailView(category: item.category, records: allRecords)
                } label: {
                    HStack(spacing: 12) {
                        CategoryIcon(category: item.category)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.category.displayName).font(.subheadline.weight(.medium))
                            ProgressView(value: item.share).tint(item.category.color)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Money.format(item.total)).font(.subheadline.monospacedDigit())
                            Text("\(item.count)×").font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecurringCard: View {
    let charges: [RecurringCharge]

    var body: some View {
        if !charges.isEmpty {
            Card(title: "Recurring charges") {
                ForEach(charges) { charge in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(charge.merchant).font(.subheadline.weight(.medium))
                            Text("Every ~\(charge.averageIntervalDays) days · last \(charge.lastDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.format(charge.typicalAmount)).font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }
}
