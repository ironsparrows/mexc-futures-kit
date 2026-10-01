/// The direction of an order.
public enum OrderSide: Int, Codable, Sendable, CaseIterable {
    /// Opens a long position.
    case openLong = 1

    /// Closes a short position.
    case closeShort = 2

    /// Opens a short position.
    case openShort = 3

    /// Closes a long position.
    case closeLong = 4
}
