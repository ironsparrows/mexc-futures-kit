/// A change to the balance of one currency.
public struct AssetUpdate: Sendable, Hashable {
    /// The currency, such as `USDT`.
    public var currency: String

    /// The balance available for new orders.
    public var availableBalance: Double

    /// The balance reserved by open orders.
    public var frozenBalance: Double

    /// The margin held by positions.
    public var positionMargin: Double

    /// The bonus balance.
    public var bonus: Double
}

extension AssetUpdate {
    init(node: JSONNode) {
        self.init(
            currency: node["currency"].stringValue,
            availableBalance: node["availableBalance"].doubleValue,
            frozenBalance: node["frozenBalance"].doubleValue,
            positionMargin: node["positionMargin"].doubleValue,
            bonus: node["bonus"].doubleValue
        )
    }
}
