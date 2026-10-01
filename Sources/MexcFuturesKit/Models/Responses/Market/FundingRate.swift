public import Foundation

/// The funding rate of a contract.
public struct FundingRate: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The current funding rate.
    public var rate: Double

    /// The time of the next funding settlement.
    public var nextSettleTime: Date
}

extension FundingRate {
    init(node: JSONNode) {
        self.init(symbol: node["symbol"].stringValue, rate: node["rate"].doubleValue, nextSettleTime: node["nextSettleTime"].dateValue)
    }
}
