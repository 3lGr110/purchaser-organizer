import Foundation

/// Minimal, storage-agnostic view of a purchase used for analytics.
public struct SpendRecord: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let date: Date
    /// Positive = money spent, negative = refund.
    public let amount: Decimal
    public let category: SpendCategory
    public let merchant: String

    public init(id: UUID = UUID(), date: Date, amount: Decimal, category: SpendCategory, merchant: String) {
        self.id = id
        self.date = date
        self.amount = amount
        self.category = category
        self.merchant = merchant
    }
}

public struct CategoryTotal: Sendable, Hashable, Identifiable {
    public var id: SpendCategory { category }
    public let category: SpendCategory
    public let total: Decimal
    public let count: Int
    /// Share of the overall total, 0...1.
    public let share: Double
}

public struct MerchantTotal: Sendable, Hashable, Identifiable {
    public var id: String { merchant }
    public let merchant: String
    public let total: Decimal
    public let count: Int
}

public struct PeriodTotal: Sendable, Hashable, Identifiable {
    public var id: Date { start }
    public let start: Date
    public let total: Decimal
}

public struct RecurringCharge: Sendable, Hashable, Identifiable {
    public var id: String { merchant }
    public let merchant: String
    public let typicalAmount: Decimal
    public let averageIntervalDays: Int
    public let occurrences: Int
    public let lastDate: Date
}

/// Pure functions that turn a list of purchases into chart-ready numbers.
public struct SpendingAnalyzer: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func records(_ records: [SpendRecord], in interval: DateInterval) -> [SpendRecord] {
        records.filter { interval.contains($0.date) && $0.date < interval.end }
    }

    public func total(_ records: [SpendRecord]) -> Decimal {
        records.reduce(Decimal.zero) { $0 + $1.amount }
    }

    public func totalsByCategory(_ records: [SpendRecord]) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: records, by: \.category)
        let overall = total(records)
        return grouped.map { category, items in
            let sum = total(items)
            let share = overall > 0 ? (sum as NSDecimalNumber).doubleValue / (overall as NSDecimalNumber).doubleValue : 0
            return CategoryTotal(category: category, total: sum, count: items.count, share: max(0, share))
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    /// Top merchants, optionally inside one category ("which supermarket do I use most?").
    public func topMerchants(_ records: [SpendRecord], category: SpendCategory? = nil, limit: Int = 10) -> [MerchantTotal] {
        let filtered = category.map { c in records.filter { $0.category == c } } ?? records
        return Dictionary(grouping: filtered, by: \.merchant)
            .map { MerchantTotal(merchant: $0.key, total: total($0.value), count: $0.value.count) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    /// Totals per calendar period (day / week / month), oldest first, including empty periods.
    public func totals(_ records: [SpendRecord], by component: Calendar.Component, count: Int, endingAt end: Date = Date()) -> [PeriodTotal] {
        guard count > 0,
              let currentStart = calendar.dateInterval(of: component, for: end)?.start else { return [] }
        var starts: [Date] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let start = calendar.date(byAdding: component, value: -offset, to: currentStart) {
                starts.append(start)
            }
        }
        var sums: [Date: Decimal] = Dictionary(uniqueKeysWithValues: starts.map { ($0, Decimal.zero) })
        for record in records {
            guard let start = calendar.dateInterval(of: component, for: record.date)?.start,
                  sums[start] != nil else { continue }
            sums[start]! += record.amount
        }
        return starts.map { PeriodTotal(start: $0, total: sums[$0] ?? 0) }
    }

    /// Average spend per month over the last `months` full months (excludes the current month).
    public func averageMonthly(_ records: [SpendRecord], category: SpendCategory? = nil, months: Int = 3, now: Date = Date()) -> Decimal {
        guard months > 0,
              let thisMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let from = calendar.date(byAdding: .month, value: -months, to: thisMonth) else { return 0 }
        let window = DateInterval(start: from, end: thisMonth)
        var scoped = self.records(records, in: window)
        if let category { scoped = scoped.filter { $0.category == category } }
        return total(scoped) / Decimal(months)
    }

    /// Finds merchants charged on a roughly regular schedule with similar amounts
    /// (subscriptions, memberships, bills).
    public func recurringCharges(_ records: [SpendRecord], minOccurrences: Int = 3) -> [RecurringCharge] {
        Dictionary(grouping: records.filter { $0.amount > 0 }, by: \.merchant).compactMap { merchant, items in
            guard items.count >= minOccurrences else { return nil }
            let sorted = items.sorted { $0.date < $1.date }
            let intervals = zip(sorted, sorted.dropFirst()).map { $1.date.timeIntervalSince($0.date) / 86_400 }
            guard let minI = intervals.min(), let maxI = intervals.max(), minI >= 6 else { return nil }
            let avg = intervals.reduce(0, +) / Double(intervals.count)
            // Intervals must be consistent (spread within 50% of the average) …
            guard (maxI - minI) <= avg * 0.5 else { return nil }
            // … and amounts must be similar (±15% of the median).
            let amounts = sorted.map(\.amount).sorted()
            let median = amounts[amounts.count / 2]
            let tolerance = median * Decimal(string: "0.15")!
            guard amounts.allSatisfy({ abs(($0 - median) as Decimal) <= tolerance }) else { return nil }
            return RecurringCharge(merchant: merchant, typicalAmount: median,
                                   averageIntervalDays: Int(avg.rounded()),
                                   occurrences: sorted.count, lastDate: sorted.last!.date)
        }
        .sorted { $0.typicalAmount > $1.typicalAmount }
    }
}
