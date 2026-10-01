public import Foundation

/// The order book of a contract.
public struct ContractDepth: Sendable, Hashable {
    /// One price level of the order book.
    public struct Level: Sendable, Hashable {
        /// The price of the level.
        public var price: Double

        /// The volume at the price, in contracts.
        public var volume: Double

        /// The number of orders at the price, when MEXC reports it.
        public var orderCount: Int?
    }

    /// The sell levels, in ascending price order.
    public var asks: [Level]

    /// The buy levels, in descending price order.
    public var bids: [Level]

    /// The order book version.
    public var version: Int64

    /// The time of the snapshot.
    public var timestamp: Date
}

extension ContractDepth {
    init(node: JSONNode) {
        self.init(
            asks: node["asks"].map(Level.init(node:)) ?? [],
            bids: node["bids"].map(Level.init(node:)) ?? [],
            version: node["version"].int64Value,
            timestamp: node["timestamp"].dateValue
        )
    }
}

extension ContractDepth.Level {
    init(node: JSONNode) {
        self.init(price: node[0].doubleValue, volume: node[1].doubleValue, orderCount: node[2].int)
    }
}
