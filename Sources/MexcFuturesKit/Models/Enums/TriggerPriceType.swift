/// The price a trigger order or TP/SL watches.
public enum TriggerPriceType: Int, Codable, Sendable, CaseIterable {
    /// The last traded price.
    case lastPrice = 1

    /// The fair price.
    case fairPrice = 2

    /// The index price.
    case indexPrice = 3
}
