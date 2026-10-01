/// The number of price levels per side of a full order book stream.
public enum DepthLimit: Int, Sendable, CaseIterable {
    /// Five price levels.
    case five = 5

    /// Ten price levels.
    case ten = 10

    /// Twenty price levels.
    case twenty = 20
}
