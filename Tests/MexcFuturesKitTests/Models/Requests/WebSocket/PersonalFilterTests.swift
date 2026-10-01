import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("PersonalFilter")
struct PersonalFilterTests {
    @Test func omitsRulesForEveryContract() {
        #expect(NSDictionary(dictionary: PersonalFilter(.asset).message) == ["filter": "asset"])
    }

    @Test func listsSymbolsAsRules() {
        let filter = PersonalFilter(.orderDeal, symbols: ["BTC_USDT", "ETH_USDT"])

        #expect(NSDictionary(dictionary: filter.message) == ["filter": "order.deal", "rules": ["BTC_USDT", "ETH_USDT"]])
    }
}
