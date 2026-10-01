extension MexcFuturesWebSocket {
    /// Subscribes to the tickers of every contract.
    public func subscribeToAllTickers() async throws(MexcFuturesError) {
        try await subscribe(to: "tickers")
    }

    /// Unsubscribes from the tickers of every contract.
    public func unsubscribeFromAllTickers() async throws(MexcFuturesError) {
        try await unsubscribe(from: "tickers")
    }

    /// Subscribes to the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToTicker(symbol: String) async throws(MexcFuturesError) {
        try await subscribe(to: "ticker", symbol: symbol)
    }

    /// Unsubscribes from the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromTicker(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "ticker", symbol: symbol)
    }

    /// Subscribes to the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToDeals(symbol: String) async throws(MexcFuturesError) {
        try await subscribe(to: "deal", symbol: symbol)
    }

    /// Unsubscribes from the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDeals(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "deal", symbol: symbol)
    }

    /// Subscribes to incremental order book updates of a contract.
    ///
    /// Without merging, MEXC pushes every change. Keep your own order book from a
    /// ``MexcFuturesClient/contractDepth(symbol:limit:)`` snapshot, apply the changes in `version` order,
    /// and reload the snapshot when a version is missing.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - merged: Whether MEXC merges changes and pushes them about every 200 ms,
    ///     instead of pushing every change.
    public func subscribeToDepth(symbol: String, merged: Bool = false) async throws(MexcFuturesError) {
        try await subscribe(to: "depth", symbol: symbol, parameters: ["compress": merged])
    }

    /// Unsubscribes from incremental order book updates of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDepth(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "depth", symbol: symbol)
    }

    /// Subscribes to full order book snapshots of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - limit: The number of price levels per side.
    public func subscribeToFullDepth(symbol: String, limit: DepthLimit = .twenty) async throws(MexcFuturesError) {
        try await subscribe(to: "depth.full", symbol: symbol, parameters: ["limit": limit.rawValue])
    }

    /// Unsubscribes from full order book snapshots of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFullDepth(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "depth.full", symbol: symbol)
    }

    /// Subscribes to the candles of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - interval: The candle interval.
    public func subscribeToKline(symbol: String, interval: KlineInterval) async throws(MexcFuturesError) {
        try await subscribe(to: "kline", symbol: symbol, parameters: ["interval": interval.rawValue], variant: interval.rawValue)
    }

    /// Unsubscribes from the candles of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromKline(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "kline", symbol: symbol)
    }

    /// Subscribes to the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await subscribe(to: "funding.rate", symbol: symbol)
    }

    /// Unsubscribes from the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "funding.rate", symbol: symbol)
    }

    /// Subscribes to the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await subscribe(to: "index.price", symbol: symbol)
    }

    /// Unsubscribes from the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "index.price", symbol: symbol)
    }

    /// Subscribes to the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await subscribe(to: "fair.price", symbol: symbol)
    }

    /// Unsubscribes from the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await unsubscribe(from: "fair.price", symbol: symbol)
    }
}
