import Foundation
import Logging
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesClient requests", .tags(.networking))
struct MexcFuturesClientRequestTests {
    enum MarketCall: CaseIterable, Sendable {
        case ticker, contractDetail, contractDepth

        var expectedURL: String {
            let base = "https://www.mexc.com/api/platform/futures/api/v1/"
            return switch self {
            case .ticker: base + "contract/ticker?symbol=BTC_USDT"
            case .contractDetail: base + "contract/detail"
            case .contractDepth: base + "contract/depth/BTC_USDT?limit=5"
            }
        }

        func perform(on client: MexcFuturesClient) async throws(MexcFuturesError) {
            switch self {
            case .ticker: _ = try await client.ticker(symbol: "BTC_USDT")
            case .contractDetail: _ = try await client.contractDetail()
            case .contractDepth: _ = try await client.contractDepth(symbol: "BTC_USDT", limit: 5)
            }
        }
    }

    enum AccountCall: CaseIterable, Sendable {
        case orderHistory, orderDeals, order, orderByExternalID, riskLimits, feeRates, accountAsset
        case openPositions, positionHistory, openOrders, accountAssets, leverage, openStopOrders, openPlanOrders

        var expectedURL: String {
            let base = "https://www.mexc.com/api/platform/futures/api/v1/"
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
            case .openOrders: base + "private/order/list/open_orders/BTC_USDT?page_num=1&page_size=100"
            case .accountAssets: base + "private/account/assets"
            case .leverage: base + "private/position/leverage?symbol=BTC_USDT"
            case .openStopOrders: base + "private/stoporder/open_orders?symbol=BTC_USDT"
            case .openPlanOrders: base + "private/planorder/list/orders?states=1&page_num=1&page_size=100&symbol=BTC_USDT"
            }
        }

        func perform(on account: MexcFuturesClient.Account) async throws(MexcFuturesError) {
            switch self {
            case .orderHistory: _ = try await account.orderHistory(OrderHistoryQuery(symbol: "BTC_USDT"))
            case .orderDeals: _ = try await account.orderDeals(OrderDealsQuery(symbol: "BTC_USDT"))
            case .order: _ = try await account.order(id: 817027833053397504)
            case .orderByExternalID: _ = try await account.order(symbol: "BTC_USDT", externalOrderID: "client/1")
            case .riskLimits: _ = try await account.riskLimits()
            case .feeRates: _ = try await account.feeRates()
            case .accountAsset: _ = try await account.accountAsset(currency: "USDT")
            case .openPositions: _ = try await account.openPositions(symbol: "ETH_USDT")
            case .positionHistory: _ = try await account.positionHistory()
            case .openOrders: _ = try await account.openOrders(symbol: "BTC_USDT")
            case .accountAssets: _ = try await account.accountAssets()
            case .leverage: _ = try await account.leverage(symbol: "BTC_USDT")
            case .openStopOrders: _ = try await account.openStopOrders(symbol: "BTC_USDT")
            case .openPlanOrders: _ = try await account.openPlanOrders(symbol: "BTC_USDT")
            }
        }
    }

    @Test(arguments: MarketCall.allCases)
    func marketRequestIsUnauthenticated(call: MarketCall) async throws {
        let transport = StubTransport()

        try await call.perform(on: .stubbed(transport))

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == call.expectedURL)
        #expect(request.value(forHTTPHeaderField: "authorization") == nil)
    }

    @Test(arguments: AccountCall.allCases)
    func accountRequestCarriesToken(call: AccountCall) async throws {
        let transport = StubTransport()

        try await call.perform(on: .stubbed(transport))

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

        let orderID = try await MexcFuturesClient.Account.stubbed(transport).submitOrder(order).get()

        let request = try #require(transport.requests.first)
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        let nonce = try #require(request.value(forHTTPHeaderField: "x-mxc-nonce"))
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/order/submit")
        #expect(body == #"{"openType":1,"price":50000,"side":1,"symbol":"BTC_USDT","type":5,"vol":1}"#)
        #expect(request.value(forHTTPHeaderField: "x-mxc-sign") == RequestSignature(body: body, authToken: "WEB-token", timestamp: nonce).sign)
        #expect(orderID == 817027833053397504)
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
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/order/cancel")
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
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/order/cancel_with_external")
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
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/order/cancel_all")
        #expect(request.httpBody == Data(expectedBody.utf8))
        #expect(request.value(forHTTPHeaderField: "x-mxc-sign") != nil)
    }
}

@Suite("MexcFuturesClient position and conditional order requests", .tags(.networking))
struct MexcFuturesClientConditionalRequestTests {
    enum SignedCall: CaseIterable, Sendable {
        case changeLeverage, addMargin, removeMargin, changeStopOrder, cancelStopOrders, cancelAllStopOrders, cancelPlanOrders, cancelAllPlanOrders

        var expected: (path: String, body: String) {
            switch self {
            case .changeLeverage: ("private/position/change_leverage", #"{"leverage":2,"openType":1,"positionType":1,"symbol":"BTC_USDT"}"#)
            case .addMargin: ("private/position/change_margin", #"{"amount":1.5,"positionId":1511503963,"type":"ADD"}"#)
            case .removeMargin: ("private/position/change_margin", #"{"amount":0.5,"positionId":1511503963,"type":"SUB"}"#)
            case .changeStopOrder: ("private/stoporder/change_plan_price", #"{"lossTrend":1,"profitTrend":1,"stopLossPrice":0.17,"stopPlanOrderId":569857826,"takeProfitPrice":0.23}"#)
            case .cancelStopOrders: ("private/stoporder/cancel", #"[{"stopPlanOrderId":569857826}]"#)
            case .cancelAllStopOrders: ("private/stoporder/cancel_all", "{}")
            case .cancelPlanOrders: ("private/planorder/cancel", #"[{"orderId":"860670920697239040","symbol":"ARB_USDT"}]"#)
            case .cancelAllPlanOrders: ("private/planorder/cancel_all", #"{"symbol":"ARB_USDT"}"#)
            }
        }

        func perform(on account: MexcFuturesClient.Account) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
            switch self {
            case .changeLeverage: try await account.changeLeverage(2, symbol: "BTC_USDT", positionType: .long, openType: .isolated)
            case .addMargin: try await account.addMargin(1.5, positionID: 1511503963)
            case .removeMargin: try await account.removeMargin(0.5, positionID: 1511503963)
            case .changeStopOrder: try await account.changeStopOrder(id: 569857826, takeProfitPrice: 0.23, stopLossPrice: 0.17)
            case .cancelStopOrders: try await account.cancelStopOrders(ids: [569857826])
            case .cancelAllStopOrders: try await account.cancelAllStopOrders()
            case .cancelPlanOrders: try await account.cancelPlanOrders(ids: [860670920697239040], symbol: "ARB_USDT")
            case .cancelAllPlanOrders: try await account.cancelAllPlanOrders(symbol: "ARB_USDT")
            }
        }
    }

    @Test(arguments: SignedCall.allCases)
    func signedCallPostsBody(call: SignedCall) async throws {
        let transport = StubTransport()

        let result = try await call.perform(on: .stubbed(transport))

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/" + call.expected.path)
        #expect(String(decoding: try #require(request.httpBody), as: UTF8.self) == call.expected.body)
        #expect(request.value(forHTTPHeaderField: "x-mxc-sign") != nil)
        #expect(throws: Never.self) { try result.get() }
    }

    @Test func placeStopOrderReturnsIdentifier() async throws {
        let transport = StubTransport(body: #"{"success":true,"code":0,"data":"569857826"}"#)

        let id = try await MexcFuturesClient.Account.stubbed(transport)
            .placeStopOrder(positionID: 1511503963, takeProfitPrice: 0.22, stopLossPrice: nil, priceType: .fairPrice)
            .get()

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/stoporder/place/v2")
        #expect(String(decoding: try #require(request.httpBody), as: UTF8.self) == #"{"lossTrend":2,"positionId":1511503963,"profitLossVolType":"SAME","profitTrend":2,"takeProfitPrice":0.22,"volType":2}"#)
        #expect(id == 569857826)
    }

    @Test func placePlanOrderReturnsIdentifier() async throws {
        let transport = StubTransport(body: #"{"success":true,"code":0,"data":"860670920697239040"}"#)
        let order = PlanOrderRequest(symbol: "ARB_USDT", side: .openLong, volume: 66, openType: .isolated, leverage: 2, triggerPrice: 0.15, triggerDirection: .lessThanOrEqual)

        let id = try await MexcFuturesClient.Account.stubbed(transport).placePlanOrder(order).get()

        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/private/planorder/place/v2")
        #expect(String(decoding: try #require(request.httpBody), as: UTF8.self) == #"{"executeCycle":2,"leverage":2,"openType":1,"orderType":5,"side":1,"symbol":"ARB_USDT","trend":1,"triggerPrice":0.15,"triggerType":2,"vol":66}"#)
        #expect(id == 860670920697239040)
    }
}

@Suite("MexcFuturesClient responses", .tags(.networking))
struct MexcFuturesClientResponseTests {
    @Test func rejectionReturnsFailureWithoutThrowing() async throws {
        let transport = StubTransport(body: #"{"success":false,"code":2005,"message":"Balance insufficient"}"#)

        let result = try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")

        guard case .failure(.rejected(let code, let message)) = result else {
            Issue.record("Expected a rejection, got \(result)")
            return
        }
        #expect(code == 2005)
        #expect(message == "Balance insufficient")
    }

    @Test func nonJSONBodyThrowsMalformedMessage() async throws {
        let transport = StubTransport(body: "OK")

        let error = try await #require(throws: MexcFuturesError.self) {
            try await MexcFuturesClient.stubbed(transport).ticker(symbol: "BTC_USDT")
        }

        guard case .malformedMessage(let text) = error else {
            Issue.record("Expected a malformed message error, got \(error)")
            return
        }
        #expect(text == "OK")
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
        #expect(transport.requests.first?.url?.absoluteString == "https://www.mexc.com/api/platform/futures/api/v1/contract/ticker?symbol=BTC_USDT")
    }
}
