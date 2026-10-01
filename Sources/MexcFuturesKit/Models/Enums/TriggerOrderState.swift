/// The lifecycle state of a trigger order or TP/SL order.
public enum TriggerOrderState: Int, Codable, Sendable, CaseIterable {
    /// The order is waiting for its trigger.
    case untriggered = 1

    /// The order is cancelled.
    case cancelled = 2

    /// The order fired and was executed.
    case executed = 3

    /// The order is no longer valid.
    case invalid = 4

    /// The order fired but its execution failed.
    case failed = 5
}
