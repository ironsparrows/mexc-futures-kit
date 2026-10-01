public import Foundation

/// A candle of a contract.
public struct Kline: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The candle interval, or `nil` when MEXC sends an interval this SDK does not know.
    public var interval: KlineInterval?

    /// The time the candle opened.
    public var openTime: Date

    /// The opening price.
    public var open: Double

    /// The closing price, or the last price of an open candle.
    public var close: Double

    /// The highest price.
    public var high: Double

    /// The lowest price.
    public var low: Double

    /// The traded amount.
    public var amount: Double

    /// The traded volume, in contracts.
    public var volume: Double
}

extension Kline {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            symbol: field("symbol").stringValue,
            interval: field("interval").string.flatMap(KlineInterval.init(rawValue:)),
            openTime: Date(timeIntervalSince1970: field("t").doubleValue),
            open: field("o").doubleValue,
            close: field("c").doubleValue,
            high: field("h").doubleValue,
            low: field("l").doubleValue,
            amount: field("a").doubleValue,
            volume: field("q").doubleValue
        )
    }
}
