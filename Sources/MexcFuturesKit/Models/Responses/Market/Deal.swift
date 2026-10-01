public import Foundation

/// A public trade of a contract.
public struct Deal: Sendable, Hashable {
    /// The trade identifier.
    public var id: Int64

    /// The trade price.
    public var price: Double

    /// The traded volume, in contracts.
    public var volume: Double

    /// The side that took liquidity, or `nil` when MEXC sends a side this SDK does not know.
    public var side: TradeSide?

    /// The time of the trade.
    public var timestamp: Date
}

extension Deal {
    init(node: JSONNode) {
        self.init(
            id: node["i"].int64Value,
            price: node["p"].doubleValue,
            volume: node["v"].doubleValue,
            side: node["T"].int.flatMap(TradeSide.init(rawValue:)),
            timestamp: node["t"].dateValue
        )
    }
}
