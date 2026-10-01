/// The lifecycle state of an order.
public enum OrderState: Int, Codable, Sendable, CaseIterable {
    /// The order is not yet acknowledged.
    case uninformed = 1

    /// The order is open and not completely filled.
    case uncompleted = 2

    /// The order is completely filled.
    case completed = 3

    /// The order is cancelled.
    case cancelled = 4

    /// The order is invalid.
    case invalid = 5
}
