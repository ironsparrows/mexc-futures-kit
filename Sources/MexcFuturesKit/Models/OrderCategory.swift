/// The origin of an order.
public enum OrderCategory: Int, Codable, Sendable, CaseIterable {
    /// An order placed by the user.
    case limit = 1

    /// An order placed by the system to take over a liquidated position.
    case systemTakeover = 2

    /// An order that closes a position.
    case closeDelegate = 3

    /// An order placed by auto-deleveraging.
    case adlReduction = 4
}
