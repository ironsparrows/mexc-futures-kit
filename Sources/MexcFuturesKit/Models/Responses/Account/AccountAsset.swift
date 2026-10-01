/// The balance of one currency.
public struct AccountAsset: Sendable, Hashable {
    /// The currency, such as `USDT`.
    public var currency: String

    /// The margin held by positions.
    public var positionMargin: Double

    /// The balance available for new orders.
    public var availableBalance: Double

    /// The cash balance.
    public var cashBalance: Double

    /// The balance reserved by open orders.
    public var frozenBalance: Double

    /// The equity, including unrealized profit and loss.
    public var equity: Double

    /// The unrealized profit and loss.
    public var unrealized: Double

    /// The bonus balance.
    public var bonus: Double
}

extension AccountAsset {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            currency: field("currency").stringValue,
            positionMargin: field("positionMargin").doubleValue,
            availableBalance: field("availableBalance").doubleValue,
            cashBalance: field("cashBalance").doubleValue,
            frozenBalance: field("frozenBalance").doubleValue,
            equity: field("equity").doubleValue,
            unrealized: field("unrealized").doubleValue,
            bonus: field("bonus").doubleValue
        )
    }
}
