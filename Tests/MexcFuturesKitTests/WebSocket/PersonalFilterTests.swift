import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("PersonalFilter")
struct PersonalFilterTests {
    @Test func omitsRulesForEveryContract() {
        #expect(PersonalFilter(.asset).json == ["filter": "asset"])
    }

    @Test func listsSymbolsAsRules() {
        let filter = PersonalFilter(.orderDeal, symbols: ["BTC_USDT", "ETH_USDT"])

        #expect(filter.json == ["filter": "order.deal", "rules": ["BTC_USDT", "ETH_USDT"]])
    }
}
