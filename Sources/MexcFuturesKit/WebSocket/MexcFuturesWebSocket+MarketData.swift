import SwiftyJSON

extension MexcFuturesWebSocket {
    /// Subscribes to the tickers of every contract.
    ///
    /// - Parameter gzip: Whether the server compresses the pushed data.
    public func subscribeToAllTickers(gzip: Bool = false) async throws(MexcFuturesError) {
        try await send(["method": "sub.tickers", "param": [String: String](), "gzip": gzip])
    }

    /// Unsubscribes from the tickers of every contract.
    public func unsubscribeFromAllTickers() async throws(MexcFuturesError) {
        try await send(["method": "unsub.tickers", "param": [String: String]()])
    }

    /// Subscribes to the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToTicker(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.ticker", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromTicker(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.ticker", "param": ["symbol": symbol]])
    }

    /// Subscribes to the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToDeals(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.deal", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDeals(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.deal", "param": ["symbol": symbol]])
    }

    /// Subscribes to incremental order book updates of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - compress: Whether the server merges updates before pushing them.
    public func subscribeToDepth(symbol: String, compress: Bool = false) async throws(MexcFuturesError) {
        try await send(["method": "sub.depth", "param": ["symbol": symbol, "compress": compress]])
    }

    /// Unsubscribes from incremental order book updates of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDepth(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.depth", "param": ["symbol": symbol]])
    }

    /// Subscribes to full order book snapshots of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - limit: The number of price levels per side.
    public func subscribeToFullDepth(symbol: String, limit: DepthLimit = .twenty) async throws(MexcFuturesError) {
        try await send(["method": "sub.depth.full", "param": ["symbol": symbol, "limit": limit.rawValue]])
    }

    /// Unsubscribes from full order book snapshots of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFullDepth(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.depth.full", "param": ["symbol": symbol]])
    }

    /// Subscribes to the candles of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - interval: The candle interval.
    public func subscribeToKline(symbol: String, interval: KlineInterval) async throws(MexcFuturesError) {
        try await send(["method": "sub.kline", "param": ["symbol": symbol, "interval": interval.rawValue]])
    }

    /// Unsubscribes from the candles of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromKline(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.kline", "param": ["symbol": symbol]])
    }

    /// Subscribes to the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.funding.rate", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.funding.rate", "param": ["symbol": symbol]])
    }

    /// Subscribes to the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.index.price", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.index.price", "param": ["symbol": symbol]])
    }

    /// Subscribes to the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.fair.price", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.fair.price", "param": ["symbol": symbol]])
    }
}
