public import Foundation

/// An order.
public struct Order: Sendable, Hashable {
    /// The order identifier.
    public var orderID: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The identifier of the position the order belongs to.
    public var positionID: Int64

    /// The order price.
    public var price: Double

    /// The order volume, in contracts.
    public var volume: Double

    /// The leverage.
    public var leverage: Int

    /// The order direction, or `nil` when MEXC sends a direction this SDK does not know.
    public var side: OrderSide?

    /// The order origin, or `nil` when MEXC sends an origin this SDK does not know.
    public var category: OrderCategory?

    /// The execution type, or `nil` when MEXC sends a type this SDK does not know.
    public var orderType: OrderType?

    /// The average fill price.
    public var dealAveragePrice: Double

    /// The filled volume, in contracts.
    public var dealVolume: Double

    /// The margin reserved for the order.
    public var orderMargin: Double

    /// The taker fee paid.
    public var takerFee: Double

    /// The maker fee paid.
    public var makerFee: Double

    /// The realized profit.
    public var profit: Double

    /// The currency of the fees.
    public var feeCurrency: String

    /// The margin mode, or `nil` when MEXC sends a mode this SDK does not know.
    public var openType: OpenType?

    /// The lifecycle state, or `nil` when MEXC sends a state this SDK does not know.
    public var state: OrderState?

    /// The client-assigned order identifier.
    public var externalOrderID: String?

    /// The error code of a failed order, `0` otherwise.
    public var errorCode: Int

    /// The margin used by the filled part of the order.
    public var usedMargin: Double

    /// The time the order was created.
    public var createTime: Date

    /// The time the order last changed.
    public var updateTime: Date

    /// The stop-loss trigger price.
    public var stopLossPrice: Double?

    /// The take-profit trigger price.
    public var takeProfitPrice: Double?
}

extension Order {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            orderID: field("orderId").int64Value,
            symbol: field("symbol").stringValue,
            positionID: field("positionId").int64Value,
            price: field("price").doubleValue,
            volume: field("vol").doubleValue,
            leverage: field("leverage").intValue,
            side: field("side").int.flatMap(OrderSide.init(rawValue:)),
            category: field("category").int.flatMap(OrderCategory.init(rawValue:)),
            orderType: field("orderType").int.flatMap(OrderType.init(rawValue:)),
            dealAveragePrice: field("dealAvgPrice").doubleValue,
            dealVolume: field("dealVol").doubleValue,
            orderMargin: field("orderMargin").doubleValue,
            takerFee: field("takerFee").doubleValue,
            makerFee: field("makerFee").doubleValue,
            profit: field("profit").doubleValue,
            feeCurrency: field("feeCurrency").stringValue,
            openType: field("openType").int.flatMap(OpenType.init(rawValue:)),
            state: field("state").int.flatMap(OrderState.init(rawValue:)),
            externalOrderID: field("externalOid").string,
            errorCode: field("errorCode").intValue,
            usedMargin: field("usedMargin").doubleValue,
            createTime: field("createTime").dateValue,
            updateTime: field("updateTime").dateValue,
            stopLossPrice: field("stopLossPrice").double,
            takeProfitPrice: field("takeProfitPrice").double
        )
    }
}
