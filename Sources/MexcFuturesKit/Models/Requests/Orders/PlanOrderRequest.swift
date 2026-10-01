/// The parameters of a trigger order, which places an order when the price crosses a trigger price.
public struct PlanOrderRequest: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The order direction.
    public var side: OrderSide

    /// The order volume, in contracts.
    public var volume: Double

    /// The margin mode.
    public var openType: OpenType

    /// The leverage. Required when the order opens a position.
    public var leverage: Int?

    /// The price that fires the order.
    public var triggerPrice: Double

    /// The direction the price must cross.
    public var triggerDirection: TriggerDirection

    /// The price that is watched.
    public var triggerPriceType: TriggerPriceType

    /// The execution type of the placed order, ``OrderType/market`` or ``OrderType/limit``.
    public var orderType: OrderType

    /// The limit price of the placed order. Required for limit orders.
    public var price: Double?

    /// How long the trigger order stays valid.
    public var validity: PlanOrderValidity

    /// The position mode, or `nil` for the account's mode.
    public var positionMode: PositionMode?

    /// Whether the placed order may only reduce a position.
    public var reduceOnly: Bool?

    /// Creates the parameters of a trigger order.
    public init(
        symbol: String,
        side: OrderSide,
        volume: Double,
        openType: OpenType,
        leverage: Int? = nil,
        triggerPrice: Double,
        triggerDirection: TriggerDirection,
        triggerPriceType: TriggerPriceType = .lastPrice,
        orderType: OrderType = .market,
        price: Double? = nil,
        validity: PlanOrderValidity = .sevenDays,
        positionMode: PositionMode? = nil,
        reduceOnly: Bool? = nil
    ) {
        self.symbol = symbol
        self.side = side
        self.volume = volume
        self.openType = openType
        self.leverage = leverage
        self.triggerPrice = triggerPrice
        self.triggerDirection = triggerDirection
        self.triggerPriceType = triggerPriceType
        self.orderType = orderType
        self.price = price
        self.validity = validity
        self.positionMode = positionMode
        self.reduceOnly = reduceOnly
    }
}

extension PlanOrderRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case volume = "vol"
        case openType
        case leverage
        case triggerPrice
        case triggerDirection = "triggerType"
        case triggerPriceType = "trend"
        case orderType
        case price
        case validity = "executeCycle"
        case positionMode
        case reduceOnly
    }
}
