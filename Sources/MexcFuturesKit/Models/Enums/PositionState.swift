/// The lifecycle state of a position.
public enum PositionState: Int, Codable, Sendable, CaseIterable {
    /// The position is held.
    case holding = 1

    /// The position is held by the system during liquidation.
    case systemHolding = 2

    /// The position is closed.
    case closed = 3
}
