import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Query parameters")
struct QueryTests {
    @Test func orderHistoryDefaultsToFirstPage() {
        #expect(OrderHistoryQuery().queryItems == [
            URLQueryItem(name: "page_num", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
        ])
    }

    @Test func orderHistoryJoinsStates() {
        let query = OrderHistoryQuery(symbol: "BTC_USDT", category: .limit, states: [.completed, .cancelled], pageNumber: 2, pageSize: 100)

        #expect(query.queryItems == [
            URLQueryItem(name: "page_num", value: "2"),
            URLQueryItem(name: "page_size", value: "100"),
            URLQueryItem(name: "symbol", value: "BTC_USDT"),
            URLQueryItem(name: "category", value: "1"),
            URLQueryItem(name: "states", value: "3,4"),
        ])
    }

    @Test func orderDealsSendsTimesInMilliseconds() {
        let query = OrderDealsQuery(
            symbol: "BTC_USDT",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: Date(timeIntervalSince1970: 1_700_003_600)
        )

        #expect(query.queryItems == [
            URLQueryItem(name: "symbol", value: "BTC_USDT"),
            URLQueryItem(name: "page_num", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "start_time", value: "1700000000000"),
            URLQueryItem(name: "end_time", value: "1700003600000"),
        ])
    }

    @Test func positionHistorySendsType() {
        let query = PositionHistoryQuery(symbol: "ETH_USDT", type: .short)

        #expect(query.queryItems == [
            URLQueryItem(name: "page_num", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "symbol", value: "ETH_USDT"),
            URLQueryItem(name: "type", value: "2"),
        ])
    }
}
