import Foundation
import Logging

extension MexcFuturesClient {
    /// A client for the private account and trading endpoints of the MEXC futures REST API.
    ///
    /// Every request carries the WEB token of a signed-in browser session. Create an account client
    /// with ``MexcFuturesClient/account(authToken:)``:
    ///
    /// ```swift
    /// let account = MexcFuturesClient().account(authToken: "WEB...")
    /// let positions = try await account.openPositions().data ?? []
    /// ```
    public struct Account: Sendable {
        private let client: MexcFuturesClient
        private let authToken: String

        init(client: MexcFuturesClient, authToken: String) {
            self.client = client
            self.authToken = authToken
        }
    }
}

extension MexcFuturesClient.Account {
    /// Submits a new order.
    ///
    /// The request is validated before it is signed and sent.
    ///
    /// - Parameter request: The parameters of the order.
    /// - Returns: The response, whose ``Response/data`` holds the order identifier.
    @discardableResult
    public func submitOrder(_ request: SubmitOrderRequest) async throws(MexcFuturesError) -> Response<Int64> {
        try request.validate()
        client.logger.debug("Submitting order", metadata: ["symbol": "\(request.symbol)", "side": "\(request.side)", "type": "\(request.type)"])
        return try await client.post(.submitOrder, authToken: authToken, body: request)
            .decode { Response(node: $0) { $0.int64 } }
    }

    /// Cancels up to 50 orders.
    ///
    /// - Parameter orderIDs: The identifiers of the orders to cancel.
    /// - Returns: The response, whose ``Response/data`` lists the result for each order.
    @discardableResult
    public func cancelOrders(_ orderIDs: [Int64]) async throws(MexcFuturesError) -> Response<[CancelOrderResult]> {
        guard !orderIDs.isEmpty else {
            throw .validation(message: "Order IDs array cannot be empty", field: "orderIDs")
        }
        guard orderIDs.count <= 50 else {
            throw .validation(message: "Cannot cancel more than 50 orders at once", field: "orderIDs")
        }
        return try await client.post(.cancelOrder, authToken: authToken, body: orderIDs.map(String.init))
            .decode { Response(node: $0) { $0.map(CancelOrderResult.init(node:)) } }
    }

    /// Cancels the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response, whose ``Response/data`` identifies the cancelled order.
    @discardableResult
    public func cancelOrder(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> Response<ExternalOrderReference> {
        try await client.post(.cancelOrderByExternalID, authToken: authToken, body: ExternalOrderReference(symbol: symbol, externalOrderID: externalOrderID))
            .decode { Response(node: $0, payload: ExternalOrderReference.init(node:)) }
    }

    /// Cancels every open order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: The response, whose ``Response/data`` holds any payload MEXC returns.
    @discardableResult
    public func cancelAllOrders(symbol: String? = nil) async throws(MexcFuturesError) -> Response<JSON> {
        try await client.post(.cancelAllOrders, authToken: authToken, body: ContractReference(symbol: symbol))
            .decode { Response(node: $0, payload: JSON.init) }
    }

    /// Returns a page of historical orders.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response, whose ``Response/data`` holds the orders.
    public func orderHistory(_ query: OrderHistoryQuery = OrderHistoryQuery()) async throws(MexcFuturesError) -> Response<[Order]> {
        try await client.get(.orderHistory, authToken: authToken, query: query.queryItems)
            .decode { Response(node: $0) { $0.map(Order.init(node:)) ?? $0["orders"].map(Order.init(node:)) } }
    }

    /// Returns a page of order executions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response, whose ``Response/data`` holds the executions.
    public func orderDeals(_ query: OrderDealsQuery) async throws(MexcFuturesError) -> Response<[OrderDeal]> {
        try await client.get(.orderDeals, authToken: authToken, query: query.queryItems)
            .decode { Response(node: $0) { $0.map(OrderDeal.init(node:)) } }
    }

    /// Returns the order with an identifier.
    ///
    /// - Parameter id: The identifier of the order.
    /// - Returns: The response, whose ``Response/data`` holds the order.
    public func order(id: Int64) async throws(MexcFuturesError) -> Response<Order> {
        try await client.get(.order, authToken: authToken, pathComponents: [String(id)])
            .decode { Response(node: $0, payload: Order.init(node:)) }
    }

    /// Returns the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response, whose ``Response/data`` holds the order.
    public func order(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> Response<Order> {
        try await client.get(.orderByExternalID, authToken: authToken, pathComponents: [symbol, externalOrderID])
            .decode { Response(node: $0, payload: Order.init(node:)) }
    }

    /// Returns the risk limits of the account.
    ///
    /// - Returns: The response, whose ``Response/data`` lists the risk limit levels of each contract.
    public func riskLimits() async throws(MexcFuturesError) -> Response<[RiskLimit]> {
        try await client.get(.riskLimit, authToken: authToken)
            .decode { root in
                Response(node: root) { data in
                    data.map(RiskLimit.init(node:)) ?? data.members()?.flatMap { $0.value.map(RiskLimit.init(node:)) ?? [] }
                }
            }
    }

    /// Returns the trading fee rates of the account.
    ///
    /// - Returns: The response, whose ``Response/data`` lists the fee rates of each contract.
    public func feeRates() async throws(MexcFuturesError) -> Response<[FeeRate]> {
        try await client.get(.feeRate, authToken: authToken)
            .decode { Response(node: $0) { $0.map(FeeRate.init(node:)) } }
    }

    /// Returns the balance of one currency.
    ///
    /// - Parameter currency: The currency, such as `USDT`.
    /// - Returns: The response, whose ``Response/data`` holds the balance.
    public func accountAsset(currency: String) async throws(MexcFuturesError) -> Response<AccountAsset> {
        try await client.get(.accountAsset, authToken: authToken, pathComponents: [currency])
            .decode { Response(node: $0, payload: AccountAsset.init(node:)) }
    }

    /// Returns the open positions.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for the positions of every contract.
    /// - Returns: The response, whose ``Response/data`` lists the positions.
    public func openPositions(symbol: String? = nil) async throws(MexcFuturesError) -> Response<[Position]> {
        try await client.get(.openPositions, authToken: authToken, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
            .decode { Response(node: $0) { $0.map(Position.init(node:)) } }
    }

    /// Returns a page of closed positions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response, whose ``Response/data`` lists the positions.
    public func positionHistory(_ query: PositionHistoryQuery = PositionHistoryQuery()) async throws(MexcFuturesError) -> Response<[Position]> {
        try await client.get(.positionHistory, authToken: authToken, query: query.queryItems)
            .decode { Response(node: $0) { $0.map(Position.init(node:)) } }
    }
}

private struct ContractReference: Encodable {
    let symbol: String?
}
