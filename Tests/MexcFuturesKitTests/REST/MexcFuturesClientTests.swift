import Foundation
import Logging
import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesClient requests", .tags(.networking))
struct MexcFuturesClientRequestTests {
    enum MarketCall: CaseIterable, Sendable {
        case ticker, contractDetail, contractDepth

        var expectedURL: String {
            let base = "https://futures.mexc.com/api/v1/"
            return switch self {
            case .ticker: base + "contract/ticker?symbol=BTC_USDT"
            case .contractDetail: base + "contract/detail"
            case .contractDepth: base + "contract/depth/BTC_USDT?limit=5"
            }
        }

        func perform(on client: MexcFuturesClient) async throws(MexcFuturesError) -> JSON {
            switch self {
            case .ticker: try await client.ticker(symbol: "BTC_USDT")
            case .contractDetail: try await client.contractDetail()
            case .contractDepth: try await client.contractDepth(symbol: "BTC_USDT", limit: 5)
            }
        }
    }

    enum AccountCall: CaseIterable, Sendable {
        case orderHistory, orderDeals, order, orderByExternalID, riskLimits, feeRates, accountAsset
        case openPositions, positionHistory

        var expectedURL: String {
            let base = "https://futures.mexc.com/api/v1/"
            return switch self {
            case .orderHistory: base + "private/order/list/history_orders?page_num=1&page_size=20&symbol=BTC_USDT"
            case .orderDeals: base + "private/order/list/order_deals?symbol=BTC_USDT&page_num=1&page_size=20"
            case .order: base + "private/order/get/817027833053397504"
            case .orderByExternalID: base + "private/order/external/BTC_USDT/client%2F1"
            case .riskLimits: base + "private/account/risk_limit"
            case .feeRates: base + "private/account/contract/fee_rate"
            case .accountAsset: base + "private/account/asset/USDT"
            case .openPositions: base + "private/position/open_positions?symbol=ETH_USDT"
            case .positionHistory: base + "private/position/list/history_positions?page_num=1&page_size=20"
            }
        }

        func perform(on account: MexcFuturesClient.Account) async throws(MexcFuturesError) -> JSON {
            switch self {
            case .orderHistory: try await account.orderHistory(OrderHistoryQuery(symbol: "BTC_USDT"))
            case .orderDeals: try await account.orderDeals(OrderDealsQuery(symbol: "BTC_USDT"))
            case .order: try await account.order(id: 817027833053397504)
            case .orderByExternalID: try await account.order(symbol: "BTC_USDT", externalOrderID: "client/1")
            case .riskLimits: try await account.riskLimits()
            case .feeRates: try await account.feeRates()
            case .accountAsset: try await account.accountAsset(currency: "USDT")
            case .openPositions: try await account.openPositions(symbol: "ETH_USDT")
            case .positionHistory: try await account.positionHistory()
            }
        }
    }

    @Test(arguments: MarketCall.allCases)
    func marketRequestIsUnauthenticated(call: MarketCall) async throws {
        let transport = StubTransport()

        _ = try await call.perform(on: .stubbed(transport))

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == call.expectedURL)
        #expect(request.value(forHTTPHeaderField: "authorization") == nil)
    }

    @Test(arguments: AccountCall.allCases)
    func accountRequestCarriesToken(call: AccountCall) async throws {
        let transport = StubTransport()

        _ = try await call.perform(on: .stubbed(transport))

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == call.expectedURL)
        #expect(request.value(forHTTPHeaderField: "authorization") == "WEB-token")
        #expect(request.httpBody == nil)
    }

    @Test func requestUsesConfiguredTimeout() async throws {
        let transport = StubTransport()
        let client = MexcFuturesClient(
            configuration: .init(timeout: .milliseconds(1500)),
            transport: transport,
            logger: .init(label: "test")
        )

        _ = try await client.ticker(symbol: "BTC_USDT")

        #expect(transport.requests.first?.timeoutInterval == 1.5)
    }

    @Test func requestSendsBrowserHeaders() async throws {
        let transport = StubTransport()

        _ = try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "origin") == "https://www.mexc.com")
        #expect(request.value(forHTTPHeaderField: "user-agent") == MexcFuturesClient.defaultHeaders["user-agent"])
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func customHeadersReplaceDefaultsButNotAuthorization() async throws {
        let transport = StubTransport()
        let client = MexcFuturesClient.stubbed(
            transport,
            userAgent: "MexcFuturesKit",
            customHeaders: ["x-language": "el-GR", "authorization": "other"]
        )

        _ = try await client.account(authToken: "WEB-token").feeRates()

        let request = try #require(transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "user-agent") == "MexcFuturesKit")
        #expect(request.value(forHTTPHeaderField: "x-language") == "el-GR")
        #expect(request.value(forHTTPHeaderField: "authorization") == "WEB-token")
    }
}

@Suite("MexcFuturesClient signed requests", .tags(.networking))
struct MexcFuturesClientSignedRequestTests {
    @Test func submitOrderPostsSignedBody() async throws {
        let transport = StubTransport(body: #"{"success":true,"code":0,"data":817027833053397504}"#)
        let order = SubmitOrderRequest(symbol: "BTC_USDT", price: 50000, volume: 1, side: .openLong, type: .market, openType: .isolated)

        let response = try await MexcFuturesClient.Account.stubbed(transport).submitOrder(order)

        let request = try #require(transport.requests.first)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        let nonce = try #require(request.value(forHTTPHeaderField: "x-mxc-nonce"))
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://futures.mexc.com/api/v1/private/order/submit")
        #expect(body == #"{"openType":1,"price":50000,"side":1,"symbol":"BTC_USDT","type":5,"vol":1}"#)
        #expect(request.value(forHTTPHeaderField: "x-mxc-sign") == RequestSignature(body: body, authToken: "WEB-token", timestamp: nonce).sign)
        #expect(response["data"].int64Value == 817027833053397504)
    }

    @Test func invalidOrderIsNotSent() async {
        let transport = StubTransport()
        let order = SubmitOrderRequest(symbol: "BTC_USDT", price: 50000, volume: 0, side: .openLong, type: .market, openType: .isolated)

        await #expect(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).submitOrder(order)
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func cancelOrdersSendsIdentifiersAsStrings() async throws {
        let transport = StubTransport()

        try await MexcFuturesClient.Account.stubbed(transport).cancelOrders([817027833053397504, 1])

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://futures.mexc.com/api/v1/private/order/cancel")
        #expect(request.httpBody == Data(#"["817027833053397504","1"]"#.utf8))
    }

    @Test(arguments: [0, 51])
    func cancelOrdersRejectsBatchSize(count: Int) async {
        let transport = StubTransport()
        let orderIDs = (0..<count).map(Int64.init)

        await #expect(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).cancelOrders(orderIDs)
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func cancelOrderByExternalIDSendsReference() async throws {
        let transport = StubTransport()

        try await MexcFuturesClient.Account.stubbed(transport).cancelOrder(symbol: "BTC_USDT", externalOrderID: "client-1")

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://futures.mexc.com/api/v1/private/order/cancel_with_external")
        #expect(request.httpBody == Data(#"{"externalOid":"client-1","symbol":"BTC_USDT"}"#.utf8))
    }

    @Test(arguments: [
        (String?.none, "{}"),
        ("BTC_USDT", #"{"symbol":"BTC_USDT"}"#),
    ])
    func cancelAllOrdersScopesToSymbol(symbol: String?, expectedBody: String) async throws {
        let transport = StubTransport()

        try await MexcFuturesClient.Account.stubbed(transport).cancelAllOrders(symbol: symbol)

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://futures.mexc.com/api/v1/private/order/cancel_all")
        #expect(request.httpBody == Data(expectedBody.utf8))
        #expect(request.value(forHTTPHeaderField: "x-mxc-sign") != nil)
    }
}

@Suite("MexcFuturesClient responses", .tags(.networking))
struct MexcFuturesClientResponseTests {
    @Test func returnsUnsuccessfulBodyWithoutThrowing() async throws {
        let transport = StubTransport(body: #"{"success":false,"code":2005,"message":"Balance insufficient"}"#)

        let response = try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")

        #expect(response["success"].boolValue == false)
        #expect(response["code"].intValue == 2005)
    }

    @Test func returnsNonJSONBodyAsString() async throws {
        let transport = StubTransport(body: "OK")

        let response = try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")

        #expect(response.string == "OK")
    }

    @Test func unauthorizedThrowsAuthentication() async throws {
        let transport = StubTransport(statusCode: 401, body: #"{"message":"Token expired"}"#)

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).riskLimits()
        }

        guard case .authentication(let message) = error else {
            Issue.record("Expected an authentication error, got \(error)")
            return
        }
        #expect(message == "Token expired")
    }

    @Test func tooManyRequestsThrowsRateLimit() async throws {
        let transport = StubTransport(statusCode: 429, body: "{}", headers: ["Retry-After": "30"])

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")
        }

        guard case .rateLimit(let message, let retryAfter) = error else {
            Issue.record("Expected a rate limit error, got \(error)")
            return
        }
        #expect(message == "Request failed with status code 429")
        #expect(retryAfter == .seconds(30))
    }

    @Test(arguments: [
        #"{"code":602,"message":"Request rejected"}"#,
        #"{"code":400,"message":"Invalid signature"}"#,
    ])
    func signatureFailureThrowsSignature(body: String) async throws {
        let transport = StubTransport(statusCode: 400, body: body)

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).cancelAllOrders()
        }

        guard case .signature = error else {
            Issue.record("Expected a signature error, got \(error)")
            return
        }
    }

    @Test func serverErrorThrowsAPIError() async throws {
        let transport = StubTransport(statusCode: 500, body: #"{"code":9999}"#)

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).order(id: 42)
        }

        guard case .api(let message, let code, let statusCode, let method, let endpoint, let response) = error else {
            Issue.record("Expected an API error, got \(error)")
            return
        }
        #expect(message == "Request failed with status code 500")
        #expect(code == 9999)
        #expect(statusCode == 500)
        #expect(method == "GET")
        #expect(endpoint == "/private/order/get/42")
        #expect(response["code"].intValue == 9999)
    }

    @Test func urlErrorThrowsNetwork() async throws {
        let transport = StubTransport(error: URLError(.timedOut))

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.Account.stubbed(transport).feeRates()
        }

        guard case .network(let urlError) = error else {
            Issue.record("Expected a network error, got \(error)")
            return
        }
        #expect(urlError.code == .timedOut)
    }

    @Test(arguments: [true, false])
    func testConnectionReportsReachability(isReachable: Bool) async {
        let transport = isReachable ? StubTransport() : StubTransport(error: URLError(.notConnectedToInternet))

        let result = await MexcFuturesClient.stubbed(transport).testConnection()

        #expect(result == isReachable)
        #expect(transport.requests.first?.url?.absoluteString == "https://futures.mexc.com/api/v1/contract/ticker?symbol=BTC_USDT")
    }
}
