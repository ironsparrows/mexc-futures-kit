public import Foundation

/// An execution of an order.
public struct OrderDeal: Sendable, Hashable {
    /// The execution identifier.
    public var id: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The order direction, or `nil` when MEXC sends a direction this SDK does not know.
    public var side: OrderSide?

    /// The executed volume, in contracts.
    public var volume: Double

    /// The execution price.
    public var price: Double

    /// The fee paid.
    public var fee: Double

    /// The currency of the fee.
    public var feeCurrency: String

    /// The realized profit.
    public var profit: Double

    /// Whether the execution took liquidity.
    public var isTaker: Bool

    /// The order origin, or `nil` when MEXC sends an origin this SDK does not know.
    public var category: OrderCategory?

    /// The identifier of the executed order.
    public var orderID: Int64

    /// The time of the execution.
    public var timestamp: Date

    /// The position mode the execution was made in, or `nil` when MEXC does not report a known mode.
    public var positionMode: PositionMode?
}

extension OrderDeal {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            id: field("id").int64Value,
            symbol: field("symbol").stringValue,
            side: field("side").int.flatMap(OrderSide.init(rawValue:)),
            volume: field("vol").doubleValue,
            price: field("price").doubleValue,
            fee: field("fee").doubleValue,
            feeCurrency: field("feeCurrency").stringValue,
            profit: field("profit").doubleValue,
            isTaker: (node["taker"].bool ?? node["isTaker"].bool) ?? false,
            category: field("category").int.flatMap(OrderCategory.init(rawValue:)),
            orderID: field("orderId").int64Value,
            timestamp: field("timestamp").dateValue,
            positionMode: field("positionMode").int.flatMap(PositionMode.init(rawValue:))
        )
    }
}
