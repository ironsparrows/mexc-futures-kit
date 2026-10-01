/// The aggressor side of a public trade.
public enum TradeSide: Int, Codable, Sendable, CaseIterable {
    /// The buyer took liquidity.
    case buy = 1

    /// The seller took liquidity.
    case sell = 2
}
