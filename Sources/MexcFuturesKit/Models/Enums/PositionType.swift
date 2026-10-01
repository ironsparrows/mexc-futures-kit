/// The direction of a position.
public enum PositionType: Int, Codable, Sendable, CaseIterable {
    /// A long position.
    case long = 1

    /// A short position.
    case short = 2
}
