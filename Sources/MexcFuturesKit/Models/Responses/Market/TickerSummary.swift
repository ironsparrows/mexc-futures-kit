public import Foundation

/// The summary ticker of one contract, as pushed for every contract at once.
public struct TickerSummary: Sendable, Hashable {
    /// The contract identifier.
    public var contractID: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The last traded price.
    public var lastPrice: Double

    /// The fair price.
    public var fairPrice: Double

    /// The index price.
    public var indexPrice: Double

    /// The highest price over 24 hours.
    public var high24Price: Double

    /// The lowest price over 24 hours.
    public var lower24Price: Double

    /// The highest allowed bid price.
    public var maxBidPrice: Double

    /// The lowest allowed ask price.
    public var minAskPrice: Double

    /// The price change rate over 24 hours.
    public var riseFallRate: Double

    /// The traded volume over 24 hours, in contracts.
    public var volume24: Double

    /// The traded amount over 24 hours.
    public var amount24: Double

    /// The time of the ticker.
    public var timestamp: Date
}

extension TickerSummary {
    init(node: JSONNode) {
        self.init(
            contractID: node["contractId"].int64Value,
            symbol: node["symbol"].stringValue,
            lastPrice: node["lastPrice"].doubleValue,
            fairPrice: node["fairPrice"].doubleValue,
            indexPrice: node["indexPrice"].doubleValue,
            high24Price: node["high24Price"].doubleValue,
            lower24Price: node["lower24Price"].doubleValue,
            maxBidPrice: node["maxBidPrice"].doubleValue,
            minAskPrice: node["minAskPrice"].doubleValue,
            riseFallRate: node["riseFallRate"].doubleValue,
            volume24: node["volume24"].doubleValue,
            amount24: node["amount24"].doubleValue,
            timestamp: node["timestamp"].dateValue
        )
    }
}
