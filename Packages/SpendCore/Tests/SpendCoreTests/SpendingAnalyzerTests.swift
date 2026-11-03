import XCTest
@testable import SpendCore

final class SpendingAnalyzerTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testTotalsByCategorySortedWithShares() {
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let records = [
            SpendRecord(date: date(2026, 10, 1), amount: 75, category: .groceries, merchant: "Kroger"),
            SpendRecord(date: date(2026, 10, 2), amount: 25, category: .fastFood, merchant: "Wendy's"),
        ]
        let totals = analyzer.totalsByCategory(records)
        XCTAssertEqual(totals.map(\.category), [.groceries, .fastFood])
        XCTAssertEqual(totals.first?.share ?? 0, 0.75, accuracy: 0.0001)
    }

    func testRefundsReduceTotals() {
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let records = [
            SpendRecord(date: date(2026, 10, 1), amount: 100, category: .shopping, merchant: "Target"),
            SpendRecord(date: date(2026, 10, 3), amount: -40, category: .shopping, merchant: "Target"),
        ]
        XCTAssertEqual(analyzer.total(records), 60)
    }

    func testMonthlyTotalsIncludeEmptyMonths() {
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let records = [
            SpendRecord(date: date(2026, 9, 15), amount: 10, category: .coffee, merchant: "Starbucks"),
            SpendRecord(date: date(2026, 11, 2), amount: 5, category: .coffee, merchant: "Starbucks"),
        ]
        let months = analyzer.totals(records, by: .month, count: 3, endingAt: date(2026, 11, 3))
        XCTAssertEqual(months.map(\.total), [10, 0, 5])
    }

    func testTopMerchantsInsideCategory() {
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let records = [
            SpendRecord(date: date(2026, 10, 1), amount: 50, category: .groceries, merchant: "Kroger"),
            SpendRecord(date: date(2026, 10, 8), amount: 80, category: .groceries, merchant: "Aldi"),
            SpendRecord(date: date(2026, 10, 9), amount: 500, category: .travel, merchant: "Delta"),
        ]
        let top = analyzer.topMerchants(records, category: .groceries)
        XCTAssertEqual(top.map(\.merchant), ["Aldi", "Kroger"])
    }

    func testRecurringChargeDetection() {
        let analyzer = SpendingAnalyzer(calendar: calendar)
        let records = (1...4).map {
            SpendRecord(date: date(2026, $0 + 5, 3), amount: Decimal(string: "15.49")!, category: .subscriptions, merchant: "Netflix")
        } + [
            SpendRecord(date: date(2026, 6, 3), amount: 12, category: .coffee, merchant: "Starbucks"),
            SpendRecord(date: date(2026, 6, 4), amount: 4, category: .coffee, merchant: "Starbucks"),
            SpendRecord(date: date(2026, 8, 20), amount: 7, category: .coffee, merchant: "Starbucks"),
        ]
        let recurring = analyzer.recurringCharges(records)
        XCTAssertEqual(recurring.map(\.merchant), ["Netflix"])
        XCTAssertEqual(recurring.first?.occurrences, 4)
    }

    func testFormulaInjectionIsNeutralized() {
        XCTAssertEqual(SpreadsheetSafety.neutralize("=HYPERLINK(\"x\")"), "'=HYPERLINK(\"x\")")
        XCTAssertEqual(SpreadsheetSafety.csvField("Joe's, Pizza"), "\"Joe's, Pizza\"")
        XCTAssertEqual(SpreadsheetSafety.csvField("Kroger"), "Kroger")
    }
}
