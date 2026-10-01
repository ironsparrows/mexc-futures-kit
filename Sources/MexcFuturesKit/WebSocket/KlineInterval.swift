/// The candle interval of a kline stream.
public enum KlineInterval: String, Sendable, CaseIterable {
    /// One-minute candles.
    case oneMinute = "Min1"

    /// Five-minute candles.
    case fiveMinutes = "Min5"

    /// Fifteen-minute candles.
    case fifteenMinutes = "Min15"

    /// Thirty-minute candles.
    case thirtyMinutes = "Min30"

    /// One-hour candles.
    case oneHour = "Min60"

    /// Four-hour candles.
    case fourHours = "Hour4"

    /// Eight-hour candles.
    case eightHours = "Hour8"

    /// One-day candles.
    case oneDay = "Day1"

    /// One-week candles.
    case oneWeek = "Week1"

    /// One-month candles.
    case oneMonth = "Month1"
}
