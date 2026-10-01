public import Foundation

/// A trigger order, which places an order when the price crosses a trigger price.
public struct PlanOrder: Sendable, Hashable {
    /// The trigger order identifier.
    public var id: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The order direction, or `nil` when MEXC sends a direction this SDK does not know.
    public var side: OrderSide?

    /// The execution type of the placed order, or `nil` when MEXC sends a type this SDK does not know.
    public var orderType: OrderType?

    /// The limit price of the placed order, when it is a limit order.
    public var price: Double?

    /// The order volume, in contracts.
    public var volume: Double

    /// The leverage.
    public var leverage: Int

    /// The margin mode, or `nil` when MEXC sends a mode this SDK does not know.
    public var openType: OpenType?

    /// The price that fires the order.
    public var triggerPrice: Double

    /// The direction the price must cross, or `nil` when MEXC sends a direction this SDK does not know.
    public var triggerDirection: TriggerDirection?

    /// The price that is watched, or `nil` when MEXC sends a price type this SDK does not know.
    public var triggerPriceType: TriggerPriceType?

    /// The lifecycle state, or `nil` when MEXC sends a state this SDK does not know.
    public var state: TriggerOrderState?

    /// How long the order stays valid, in hours.
    public var executeCycle: Int

    /// Whether the placed order may only reduce a position.
    public var reduceOnly: Bool

    /// The position mode, or `nil` when MEXC does not report a known mode.
    public var positionMode: PositionMode?

    /// The time the trigger order was created.
    public var createTime: Date

    /// The time the trigger order last changed.
    public var updateTime: Date
}

extension PlanOrder {
    init(node: JSONNode) {
        self.init(
            id: node["id"].int64Value,
            symbol: node["symbol"].stringValue,
            side: node["side"].int.flatMap(OrderSide.init(rawValue:)),
            orderType: node["orderType"].int.flatMap(OrderType.init(rawValue:)),
            price: node["price"].double,
            volume: node["vol"].doubleValue,
            leverage: node["leverage"].intValue,
            openType: node["openType"].int.flatMap(OpenType.init(rawValue:)),
            triggerPrice: node["triggerPrice"].doubleValue,
            triggerDirection: node["triggerType"].int.flatMap(TriggerDirection.init(rawValue:)),
            triggerPriceType: node["trend"].int.flatMap(TriggerPriceType.init(rawValue:)),
            state: node["state"].int.flatMap(TriggerOrderState.init(rawValue:)),
            executeCycle: node["executeCycle"].intValue,
            reduceOnly: node["reduceOnly"].boolValue,
            positionMode: node["positionMode"].int.flatMap(PositionMode.init(rawValue:)),
            createTime: node["createTime"].dateValue,
            updateTime: node["updateTime"].dateValue
        )
    }
}
