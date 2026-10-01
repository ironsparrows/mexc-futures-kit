/// The liquidation risk of a position.
public struct LiquidationRisk: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The position identifier.
    public var positionID: Int64

    /// The liquidation price.
    public var liquidatePrice: Double

    /// The margin ratio. The position is liquidated when it reaches 1.
    public var marginRatio: Double

    /// The auto-deleveraging level from 0 to 5.
    public var adlLevel: Int
}

extension LiquidationRisk {
    init(node: JSONNode) {
        self.init(
            symbol: node["symbol"].stringValue,
            positionID: node["positionId"].int64Value,
            liquidatePrice: node["liquidatePrice"].doubleValue,
            marginRatio: node["marginRatio"].doubleValue,
            adlLevel: node["adlLevel"].intValue
        )
    }
}
