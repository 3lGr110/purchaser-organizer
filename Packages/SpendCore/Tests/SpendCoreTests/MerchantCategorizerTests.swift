import XCTest
@testable import SpendCore

final class MerchantCategorizerTests: XCTestCase {
    let categorizer = MerchantCategorizer()

    func testSupermarketsAreGroceriesWithBrandName() {
        let cases: [(String, String)] = [
            ("KROGER #0421", "Kroger"),
            ("TRADER JOE'S #552 QPS", "Trader Joe's"),
            ("WHOLEFDS MKT 10234", "Whole Foods"),
            ("WAL-MART SUPERCENTER 1234", "Walmart"),
            ("H-E-B #431 AUSTIN TX", "H-E-B"),
        ]
        for (raw, brand) in cases {
            let result = categorizer.categorize(merchant: raw)
            XCTAssertEqual(result.category, .groceries, raw)
            XCTAssertEqual(result.merchantName, brand, raw)
            XCTAssertEqual(result.source, .brandCatalog, raw)
        }
    }

    func testFastFoodBrands() {
        XCTAssertEqual(categorizer.categorize(merchant: "McDonald's F12345").category, .fastFood)
        XCTAssertEqual(categorizer.categorize(merchant: "CHICK-FIL-A #01822").merchantName, "Chick-fil-A")
        XCTAssertEqual(categorizer.categorize(merchant: "TACO BELL 031234").category, .fastFood)
    }

    func testLongestPatternWins() {
        XCTAssertEqual(categorizer.categorize(merchant: "UBER EATS").category, .restaurants)
        XCTAssertEqual(categorizer.categorize(merchant: "UBER *TRIP").category, .transport)
        XCTAssertEqual(categorizer.categorize(merchant: "AMAZON PRIME*2K4").category, .subscriptions)
        XCTAssertEqual(categorizer.categorize(merchant: "AMZN Mktp US*2K4AB").category, .onlineShopping)
    }

    func testProcessorPrefixesAreStripped() {
        let result = categorizer.categorize(merchant: "SQ *BLUE BOTTLE COFFEE")
        XCTAssertEqual(result.merchantName, "Blue Bottle")
        XCTAssertEqual(result.category, .coffee)
    }

    func testMerchantCategoryCodeFallback() {
        let result = categorizer.categorize(merchant: "LA ESQUINITA", merchantCategoryCode: 5411)
        XCTAssertEqual(result.category, .groceries)
        XCTAssertEqual(result.source, .merchantCode)
    }

    func testKeywordFallback() {
        XCTAssertEqual(categorizer.categorize(merchant: "ROSAS PIZZA").category, .fastFood)
        XCTAssertEqual(categorizer.categorize(merchant: "SUNRISE SUPERMARKET").category, .groceries)
    }

    func testUserRuleOverridesEverything() {
        var custom = MerchantCategorizer()
        custom.userRules[MerchantNormalizer.matchKey(for: "TARGET 00012")] = .groceries
        let result = custom.categorize(merchant: "TARGET 00012")
        XCTAssertEqual(result.category, .groceries)
        XCTAssertEqual(result.source, .userRule)
    }

    func testUnknownMerchantIsOther() {
        let result = categorizer.categorize(merchant: "XQZ HOLDINGS LLC")
        XCTAssertEqual(result.category, .other)
        XCTAssertEqual(result.source, .fallback)
    }

    func testSanitizeStripsControlCharactersAndCapsLength() {
        let hostile = "KROGER\u{0000}\u{001B}[31m" + String(repeating: "A", count: 5_000)
        let clean = MerchantNormalizer.sanitize(hostile)
        XCTAssertLessThanOrEqual(clean.count, MerchantNormalizer.maxInputLength)
        XCTAssertFalse(clean.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
    }
}
