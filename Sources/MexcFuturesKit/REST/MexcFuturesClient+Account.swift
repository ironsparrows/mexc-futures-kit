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
    /// let positions = try await account.openPositions().get()
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
    /// - Returns: The order identifier, or MEXC's rejection.
    @discardableResult
    public func submitOrder(_ request: SubmitOrderRequest) async throws(MexcFuturesError) -> Result<Int64, MexcFuturesError> {
        try request.validate()
        client.logger.debug("Submitting order", metadata: ["symbol": "\(request.symbol)", "side": "\(request.side)", "type": "\(request.type)"])
        return try await client.post(.submitOrder, authToken: authToken, body: request)
            .decode { Result(response: $0) { $0.int64 } }
    }

    /// Cancels up to 50 orders.
    ///
    /// - Parameter orderIDs: The identifiers of the orders to cancel.
    /// - Returns: The result for each order, or MEXC's rejection.
    @discardableResult
    public func cancelOrders(_ orderIDs: [Int64]) async throws(MexcFuturesError) -> Result<[CancelOrderResult], MexcFuturesError> {
        guard !orderIDs.isEmpty else {
            throw .validation(message: "Order IDs array cannot be empty", field: "orderIDs")
        }
        guard orderIDs.count <= 50 else {
            throw .validation(message: "Cannot cancel more than 50 orders at once", field: "orderIDs")
        }
        return try await client.post(.cancelOrder, authToken: authToken, body: orderIDs.map(String.init))
            .decode { Result(response: $0) { $0.map(CancelOrderResult.init(node:)) } }
    }

    /// Cancels the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The cancelled order, or MEXC's rejection.
    @discardableResult
    public func cancelOrder(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> Result<ExternalOrderReference, MexcFuturesError> {
        try await client.post(.cancelOrderByExternalID, authToken: authToken, body: ExternalOrderReference(symbol: symbol, externalOrderID: externalOrderID))
            .decode { Result(response: $0) { $0.object(ExternalOrderReference.init(node:)) ?? ExternalOrderReference(symbol: symbol, externalOrderID: externalOrderID) } }
    }

    /// Cancels every open order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func cancelAllOrders(symbol: String? = nil) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.cancelAllOrders, authToken: authToken, body: ContractReference(symbol: symbol))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Returns a page of historical orders.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The orders, or MEXC's rejection.
    public func orderHistory(_ query: OrderHistoryQuery = OrderHistoryQuery()) async throws(MexcFuturesError) -> Result<[Order], MexcFuturesError> {
        try await client.get(.orderHistory, authToken: authToken, query: query.queryItems)
            .decode { Result(response: $0) { $0.map(Order.init(node:)) ?? $0["orders"].map(Order.init(node:)) } }
    }

    /// Returns a page of order executions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The executions, or MEXC's rejection.
    public func orderDeals(_ query: OrderDealsQuery) async throws(MexcFuturesError) -> Result<[OrderDeal], MexcFuturesError> {
        try await client.get(.orderDeals, authToken: authToken, query: query.queryItems)
            .decode { Result(response: $0) { $0.map(OrderDeal.init(node:)) } }
    }

    /// Returns the order with an identifier.
    ///
    /// - Parameter id: The identifier of the order.
    /// - Returns: The order, `nil` when MEXC has no such order, or MEXC's rejection.
    public func order(id: Int64) async throws(MexcFuturesError) -> Result<Order?, MexcFuturesError> {
        try await client.get(.order, authToken: authToken, pathComponents: [String(id)])
            .decode { Result(response: $0) { .some($0.object(Order.init(node:))) } }
    }

    /// Returns the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The order, `nil` when MEXC has no such order, or MEXC's rejection.
    public func order(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> Result<Order?, MexcFuturesError> {
        try await client.get(.orderByExternalID, authToken: authToken, pathComponents: [symbol, externalOrderID])
            .decode { Result(response: $0) { .some($0.object(Order.init(node:))) } }
    }

    /// Returns the risk limits of the account.
    ///
    /// - Returns: The risk limit levels of each contract, or MEXC's rejection.
    public func riskLimits() async throws(MexcFuturesError) -> Result<[RiskLimit], MexcFuturesError> {
        try await client.get(.riskLimit, authToken: authToken)
            .decode { root in
                Result(response: root) { data in
                    data.map(RiskLimit.init(node:)) ?? data.members()?.flatMap { $0.value.map(RiskLimit.init(node:)) ?? [] }
                }
            }
    }

    /// Returns the trading fee rates of the account.
    ///
    /// - Returns: The fee rates of each contract, or MEXC's rejection.
    public func feeRates() async throws(MexcFuturesError) -> Result<[FeeRate], MexcFuturesError> {
        try await client.get(.feeRate, authToken: authToken)
            .decode { Result(response: $0) { $0.map(FeeRate.init(node:)) } }
    }

    /// Returns the balance of one currency.
    ///
    /// - Parameter currency: The currency, such as `USDT`.
    /// - Returns: The balance, or MEXC's rejection.
    public func accountAsset(currency: String) async throws(MexcFuturesError) -> Result<AccountAsset, MexcFuturesError> {
        try await client.get(.accountAsset, authToken: authToken, pathComponents: [currency])
            .decode { Result(response: $0) { $0.object(AccountAsset.init(node:)) } }
    }

    /// Returns the open positions.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for the positions of every contract.
    /// - Returns: The positions, or MEXC's rejection.
    public func openPositions(symbol: String? = nil) async throws(MexcFuturesError) -> Result<[Position], MexcFuturesError> {
        try await client.get(.openPositions, authToken: authToken, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
            .decode { Result(response: $0) { $0.map(Position.init(node:)) } }
    }

    /// Returns a page of closed positions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The positions, or MEXC's rejection.
    public func positionHistory(_ query: PositionHistoryQuery = PositionHistoryQuery()) async throws(MexcFuturesError) -> Result<[Position], MexcFuturesError> {
        try await client.get(.positionHistory, authToken: authToken, query: query.queryItems)
            .decode { Result(response: $0) { $0.map(Position.init(node:)) } }
    }
}

private struct ContractReference: Encodable {
    let symbol: String?
}
