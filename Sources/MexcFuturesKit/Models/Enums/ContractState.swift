/// The trading state of a contract.
public enum ContractState: Int, Codable, Sendable, CaseIterable {
    /// The contract is open for trading.
    case enabled = 0

    /// The contract is being delivered.
    case delivering = 1

    /// The contract delivery is complete.
    case delivered = 2

    /// The contract is delisted.
    case offline = 3

    /// Trading is paused.
    case paused = 4
}
