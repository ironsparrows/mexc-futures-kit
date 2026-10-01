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
    /// let positions = try await account.openPositions()
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
    /// - Returns: The response body, whose `data` field holds the order identifier.
    @discardableResult
    public func submitOrder(_ request: SubmitOrderRequest) async throws(MexcFuturesError) -> JSON {
        try request.validate()
        client.logger.debug("Submitting order", metadata: ["symbol": "\(request.symbol)", "side": "\(request.side)", "type": "\(request.type)"])
        return try await client.post(.submitOrder, authToken: authToken, body: request)
    }

    /// Cancels up to 50 orders.
    ///
    /// - Parameter orderIDs: The identifiers of the orders to cancel.
    /// - Returns: The response body, whose `data` field lists the result for each order.
    @discardableResult
    public func cancelOrders(_ orderIDs: [Int64]) async throws(MexcFuturesError) -> JSON {
        guard !orderIDs.isEmpty else {
            throw .validation(message: "Order IDs array cannot be empty", field: "orderIDs")
        }
        guard orderIDs.count <= 50 else {
            throw .validation(message: "Cannot cancel more than 50 orders at once", field: "orderIDs")
        }
        return try await client.post(.cancelOrder, authToken: authToken, body: orderIDs.map(String.init))
    }

    /// Cancels the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response body.
    @discardableResult
    public func cancelOrder(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> JSON {
        try await client.post(.cancelOrderByExternalID, authToken: authToken, body: ExternalOrderReference(symbol: symbol, externalOid: externalOrderID))
    }

    /// Cancels every open order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: The response body.
    @discardableResult
    public func cancelAllOrders(symbol: String? = nil) async throws(MexcFuturesError) -> JSON {
        try await client.post(.cancelAllOrders, authToken: authToken, body: ContractReference(symbol: symbol))
    }

    /// Returns a page of historical orders.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field holds the orders.
    public func orderHistory(_ query: OrderHistoryQuery = OrderHistoryQuery()) async throws(MexcFuturesError) -> JSON {
        try await client.get(.orderHistory, authToken: authToken, query: query.queryItems)
    }

    /// Returns a page of order executions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field holds the executions.
    public func orderDeals(_ query: OrderDealsQuery) async throws(MexcFuturesError) -> JSON {
        try await client.get(.orderDeals, authToken: authToken, query: query.queryItems)
    }

    /// Returns the order with an identifier.
    ///
    /// - Parameter id: The identifier of the order.
    /// - Returns: The response body, whose `data` field holds the order.
    public func order(id: Int64) async throws(MexcFuturesError) -> JSON {
        try await client.get(.order, authToken: authToken, pathComponents: [String(id)])
    }

    /// Returns the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response body, whose `data` field holds the order.
    public func order(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> JSON {
        try await client.get(.orderByExternalID, authToken: authToken, pathComponents: [symbol, externalOrderID])
    }

    /// Returns the risk limits of the account.
    ///
    /// - Returns: The response body, whose `data` field lists the risk limit of each contract.
    public func riskLimits() async throws(MexcFuturesError) -> JSON {
        try await client.get(.riskLimit, authToken: authToken)
    }

    /// Returns the trading fee rates of the account.
    ///
    /// - Returns: The response body, whose `data` field lists the fee rates of each contract.
    public func feeRates() async throws(MexcFuturesError) -> JSON {
        try await client.get(.feeRate, authToken: authToken)
    }

    /// Returns the balance of one currency.
    ///
    /// - Parameter currency: The currency, such as `USDT`.
    /// - Returns: The response body, whose `data` field holds the balance.
    public func accountAsset(currency: String) async throws(MexcFuturesError) -> JSON {
        try await client.get(.accountAsset, authToken: authToken, pathComponents: [currency])
    }

    /// Returns the open positions.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for the positions of every contract.
    /// - Returns: The response body, whose `data` field lists the positions.
    public func openPositions(symbol: String? = nil) async throws(MexcFuturesError) -> JSON {
        try await client.get(.openPositions, authToken: authToken, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
    }

    /// Returns a page of closed positions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field lists the positions.
    public func positionHistory(_ query: PositionHistoryQuery = PositionHistoryQuery()) async throws(MexcFuturesError) -> JSON {
        try await client.get(.positionHistory, authToken: authToken, query: query.queryItems)
    }
}

private struct ExternalOrderReference: Encodable {
    let symbol: String
    let externalOid: String
}

private struct ContractReference: Encodable {
    let symbol: String?
}
