/// The trading fee rates of a contract.
public struct FeeRate: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The taker fee rate.
    public var takerFeeRate: Double

    /// The maker fee rate.
    public var makerFeeRate: Double
}

extension FeeRate {
    init(node: JSONNode) {
        self.init(symbol: node["symbol"].stringValue, takerFeeRate: node["takerFeeRate"].doubleValue, makerFeeRate: node["makerFeeRate"].doubleValue)
    }
}
