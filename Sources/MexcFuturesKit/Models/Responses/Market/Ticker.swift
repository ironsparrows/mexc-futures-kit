public import Foundation

/// The ticker of a contract.
public struct Ticker: Sendable, Hashable {
    /// The price changes of a contract over several periods.
    public struct RiseFallRates: Sendable, Hashable {
        /// The time zone the periods are measured in.
        public var zone: String

        /// The change rate of the current period.
        public var rate: Double

        /// The change value of the current period.
        public var value: Double

        /// The change rate over 7 days.
        public var rate7Days: Double

        /// The change rate over 30 days.
        public var rate30Days: Double

        /// The change rate over 90 days.
        public var rate90Days: Double

        /// The change rate over 180 days.
        public var rate180Days: Double

        /// The change rate over 365 days.
        public var rate365Days: Double
    }

    /// The contract identifier, when MEXC reports it.
    public var contractID: Int64?

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The last traded price.
    public var lastPrice: Double

    /// The best bid price.
    public var bid1: Double

    /// The best ask price.
    public var ask1: Double

    /// The traded volume over 24 hours, in contracts.
    public var volume24: Double

    /// The traded amount over 24 hours.
    public var amount24: Double

    /// The open interest, in contracts.
    public var holdVolume: Double

    /// The lowest price over 24 hours.
    public var lower24Price: Double

    /// The highest price over 24 hours.
    public var high24Price: Double

    /// The price change rate over 24 hours.
    public var riseFallRate: Double

    /// The price change over 24 hours.
    public var riseFallValue: Double

    /// The index price.
    public var indexPrice: Double

    /// The fair price.
    public var fairPrice: Double

    /// The current funding rate.
    public var fundingRate: Double

    /// The highest allowed bid price.
    public var maxBidPrice: Double

    /// The lowest allowed ask price.
    public var minAskPrice: Double

    /// The time of the ticker.
    public var timestamp: Date

    /// The price changes over several periods.
    public var riseFallRates: RiseFallRates

    /// The change rates in each time zone.
    public var riseFallRatesOfTimezone: [Double]
}

extension Ticker {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            contractID: field("contractId").int64,
            symbol: field("symbol").stringValue,
            lastPrice: field("lastPrice").doubleValue,
            bid1: field("bid1").doubleValue,
            ask1: field("ask1").doubleValue,
            volume24: field("volume24").doubleValue,
            amount24: field("amount24").doubleValue,
            holdVolume: field("holdVol").doubleValue,
            lower24Price: field("lower24Price").doubleValue,
            high24Price: field("high24Price").doubleValue,
            riseFallRate: field("riseFallRate").doubleValue,
            riseFallValue: field("riseFallValue").doubleValue,
            indexPrice: field("indexPrice").doubleValue,
            fairPrice: field("fairPrice").doubleValue,
            fundingRate: field("fundingRate").doubleValue,
            maxBidPrice: field("maxBidPrice").doubleValue,
            minAskPrice: field("minAskPrice").doubleValue,
            timestamp: field("timestamp").dateValue,
            riseFallRates: RiseFallRates(node: field("riseFallRates"), ticker: node),
            riseFallRatesOfTimezone: field("riseFallRatesOfTimezone").map(\.doubleValue) ?? []
        )
    }
}

extension Ticker.RiseFallRates {
    init(node: JSONNode, ticker: JSONNode) {
        guard node.isObject else {
            self.init(
                zone: ticker["zone"].stringValue,
                rate: node[0].doubleValue,
                value: ticker["riseFallValue"].doubleValue,
                rate7Days: node[1].doubleValue,
                rate30Days: node[2].doubleValue,
                rate90Days: node[3].doubleValue,
                rate180Days: node[4].doubleValue,
                rate365Days: node[5].doubleValue
            )
            return
        }
        var field = JSONObjectReader(node)
        self.init(
            zone: field("zone").stringValue,
            rate: field("r").doubleValue,
            value: field("v").doubleValue,
            rate7Days: field("r7").doubleValue,
            rate30Days: field("r30").doubleValue,
            rate90Days: field("r90").doubleValue,
            rate180Days: field("r180").doubleValue,
            rate365Days: field("r365").doubleValue
        )
    }
}
