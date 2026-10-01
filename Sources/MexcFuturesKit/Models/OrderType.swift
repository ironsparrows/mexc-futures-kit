/// The execution type of an order.
public enum OrderType: Int, Codable, Sendable, CaseIterable {
    /// A limit order.
    case limit = 1

    /// A maker-only order that is cancelled if it would take liquidity.
    case postOnly = 2

    /// An order that fills what it can immediately and cancels the rest.
    case immediateOrCancel = 3

    /// An order that fills completely or is cancelled completely.
    case fillOrKill = 4

    /// A market order.
    case market = 5

    /// A market order whose unfilled part becomes a limit order at the current price.
    case marketToLimit = 6
}
