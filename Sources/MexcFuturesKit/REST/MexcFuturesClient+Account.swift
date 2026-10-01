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

    /// Returns a page of open orders.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, or `nil` for the orders of every contract.
    ///   - pageNumber: The one-based page number.
    ///   - pageSize: The number of orders per page, at most 100.
    /// - Returns: The orders, or MEXC's rejection.
    public func openOrders(symbol: String? = nil, pageNumber: Int = 1, pageSize: Int = 100) async throws(MexcFuturesError) -> Result<[Order], MexcFuturesError> {
        try await client.get(.openOrders, authToken: authToken, pathComponents: symbol.map { [$0] } ?? [], query: [
            URLQueryItem(name: "page_num", value: String(pageNumber)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ])
        .decode { Result(response: $0) { $0.map(Order.init(node:)) } }
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

    /// Returns the balance of every currency.
    ///
    /// - Returns: The balances, or MEXC's rejection.
    public func accountAssets() async throws(MexcFuturesError) -> Result<[AccountAsset], MexcFuturesError> {
        try await client.get(.accountAssets, authToken: authToken)
            .decode { Result(response: $0) { $0.map(AccountAsset.init(node:)) } }
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

    /// Returns the leverage of both sides of a contract.
    ///
    /// - Parameter symbol: The contract symbol.
    /// - Returns: The leverage of the long and the short side, or MEXC's rejection.
    public func leverage(symbol: String) async throws(MexcFuturesError) -> Result<[PositionLeverage], MexcFuturesError> {
        try await client.get(.leverage, authToken: authToken, query: [URLQueryItem(name: "symbol", value: symbol)])
            .decode { Result(response: $0) { $0.map(PositionLeverage.init(node:)) } }
    }

    /// Changes the leverage of one side of a contract.
    ///
    /// - Parameters:
    ///   - leverage: The new leverage.
    ///   - symbol: The contract symbol.
    ///   - positionType: The side to change.
    ///   - openType: The margin mode of the side.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func changeLeverage(_ leverage: Int, symbol: String, positionType: PositionType, openType: OpenType) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.changeLeverage, authToken: authToken, body: LeverageChange(leverage: leverage, symbol: symbol, positionType: positionType, openType: openType))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Adds margin to an isolated position.
    ///
    /// - Parameters:
    ///   - amount: The margin to add, in the settlement currency.
    ///   - positionID: The position identifier.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func addMargin(_ amount: Double, positionID: Int64) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.changeMargin, authToken: authToken, body: MarginChange(positionId: positionID, amount: amount, type: "ADD"))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Removes margin from an isolated position.
    ///
    /// - Parameters:
    ///   - amount: The margin to remove, in the settlement currency.
    ///   - positionID: The position identifier.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func removeMargin(_ amount: Double, positionID: Int64) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.changeMargin, authToken: authToken, body: MarginChange(positionId: positionID, amount: amount, type: "SUB"))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Places a take-profit and stop-loss order on a whole position.
    ///
    /// - Parameters:
    ///   - positionID: The position identifier.
    ///   - takeProfitPrice: The take-profit trigger price, or `nil` for no take-profit.
    ///   - stopLossPrice: The stop-loss trigger price, or `nil` for no stop-loss.
    ///   - priceType: The price both triggers watch.
    /// - Returns: The TP/SL order identifier, or MEXC's rejection.
    @discardableResult
    public func placeStopOrder(
        positionID: Int64,
        takeProfitPrice: Double?,
        stopLossPrice: Double?,
        priceType: TriggerPriceType = .lastPrice
    ) async throws(MexcFuturesError) -> Result<Int64, MexcFuturesError> {
        let body = StopOrderPlacement(positionId: positionID, takeProfitPrice: takeProfitPrice, stopLossPrice: stopLossPrice, profitTrend: priceType, lossTrend: priceType)
        return try await client.post(.placeStopOrder, authToken: authToken, body: body)
            .decode { Result(response: $0) { $0.int64 } }
    }

    /// Changes the trigger prices of a take-profit and stop-loss order.
    ///
    /// - Parameters:
    ///   - id: The TP/SL order identifier.
    ///   - takeProfitPrice: The new take-profit trigger price, or `nil` for no take-profit.
    ///   - stopLossPrice: The new stop-loss trigger price, or `nil` for no stop-loss.
    ///   - priceType: The price both triggers watch.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func changeStopOrder(
        id: Int64,
        takeProfitPrice: Double?,
        stopLossPrice: Double?,
        priceType: TriggerPriceType = .lastPrice
    ) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        let body = StopOrderChange(stopPlanOrderId: id, takeProfitPrice: takeProfitPrice, stopLossPrice: stopLossPrice, profitTrend: priceType, lossTrend: priceType)
        return try await client.post(.changeStopOrder, authToken: authToken, body: body)
            .decode { Result(response: $0) { _ in () } }
    }

    /// Cancels take-profit and stop-loss orders.
    ///
    /// - Parameter ids: The TP/SL order identifiers.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func cancelStopOrders(ids: [Int64]) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.cancelStopOrders, authToken: authToken, body: ids.map(StopOrderReference.init(stopPlanOrderId:)))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Cancels every take-profit and stop-loss order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func cancelAllStopOrders(symbol: String? = nil) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.cancelAllStopOrders, authToken: authToken, body: ContractReference(symbol: symbol))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Returns the open take-profit and stop-loss orders.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for the orders of every contract.
    /// - Returns: The TP/SL orders, or MEXC's rejection.
    public func openStopOrders(symbol: String? = nil) async throws(MexcFuturesError) -> Result<[StopOrder], MexcFuturesError> {
        try await client.get(.openStopOrders, authToken: authToken, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
            .decode { Result(response: $0) { $0.map(StopOrder.init(node:)) } }
    }

    /// Places a trigger order.
    ///
    /// - Parameter request: The parameters of the trigger order.
    /// - Returns: The trigger order identifier, or MEXC's rejection.
    @discardableResult
    public func placePlanOrder(_ request: PlanOrderRequest) async throws(MexcFuturesError) -> Result<Int64, MexcFuturesError> {
        try await client.post(.placePlanOrder, authToken: authToken, body: request)
            .decode { Result(response: $0) { $0.int64 } }
    }

    /// Cancels trigger orders of a contract.
    ///
    /// - Parameters:
    ///   - ids: The trigger order identifiers.
    ///   - symbol: The contract symbol of the orders.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func cancelPlanOrders(ids: [Int64], symbol: String) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.cancelPlanOrders, authToken: authToken, body: ids.map { PlanOrderReference(symbol: symbol, orderId: String($0)) })
            .decode { Result(response: $0) { _ in () } }
    }

    /// Cancels every trigger order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: Success, or MEXC's rejection.
    @discardableResult
    public func cancelAllPlanOrders(symbol: String? = nil) async throws(MexcFuturesError) -> Result<Void, MexcFuturesError> {
        try await client.post(.cancelAllPlanOrders, authToken: authToken, body: ContractReference(symbol: symbol))
            .decode { Result(response: $0) { _ in () } }
    }

    /// Returns a page of untriggered trigger orders.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, or `nil` for the orders of every contract.
    ///   - pageNumber: The one-based page number.
    ///   - pageSize: The number of orders per page, at most 100.
    /// - Returns: The trigger orders, or MEXC's rejection.
    public func openPlanOrders(symbol: String? = nil, pageNumber: Int = 1, pageSize: Int = 100) async throws(MexcFuturesError) -> Result<[PlanOrder], MexcFuturesError> {
        var query = [
            URLQueryItem(name: "states", value: String(TriggerOrderState.untriggered.rawValue)),
            URLQueryItem(name: "page_num", value: String(pageNumber)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        if let symbol {
            query.append(URLQueryItem(name: "symbol", value: symbol))
        }
        return try await client.get(.planOrders, authToken: authToken, query: query)
            .decode { Result(response: $0) { $0.map(PlanOrder.init(node:)) } }
    }
}

private struct ContractReference: Encodable {
    let symbol: String?
}

private struct LeverageChange: Encodable {
    let leverage: Int
    let symbol: String
    let positionType: PositionType
    let openType: OpenType
}

private struct MarginChange: Encodable {
    let positionId: Int64
    let amount: Double
    let type: String
}

private struct StopOrderPlacement: Encodable {
    let positionId: Int64
    let takeProfitPrice: Double?
    let stopLossPrice: Double?
    let profitTrend: TriggerPriceType
    let lossTrend: TriggerPriceType
    let volType = 2
    let profitLossVolType = "SAME"
}

private struct StopOrderChange: Encodable {
    let stopPlanOrderId: Int64
    let takeProfitPrice: Double?
    let stopLossPrice: Double?
    let profitTrend: TriggerPriceType
    let lossTrend: TriggerPriceType
}

private struct StopOrderReference: Encodable {
    let stopPlanOrderId: Int64
}

private struct PlanOrderReference: Encodable {
    let symbol: String
    let orderId: String
}
