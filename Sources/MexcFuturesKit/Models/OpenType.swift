/// The margin mode of a position.
public enum OpenType: Int, Codable, Sendable, CaseIterable {
    /// Isolated margin.
    case isolated = 1

    /// Cross margin.
    case cross = 2
}
