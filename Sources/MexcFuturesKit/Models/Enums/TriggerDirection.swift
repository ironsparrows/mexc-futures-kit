/// The direction the price must cross to fire a trigger order.
public enum TriggerDirection: Int, Codable, Sendable, CaseIterable {
    /// The order fires when the price rises to the trigger price or above.
    case greaterThanOrEqual = 1

    /// The order fires when the price falls to the trigger price or below.
    case lessThanOrEqual = 2
}
