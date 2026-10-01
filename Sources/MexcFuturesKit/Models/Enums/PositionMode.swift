/// The position mode of an account.
public enum PositionMode: Int, Codable, Sendable, CaseIterable {
    /// Long and short positions are held separately.
    case hedge = 1

    /// One net position is held per contract.
    case oneWay = 2
}
