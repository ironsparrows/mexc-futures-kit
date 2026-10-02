public import Foundation

extension MexcFuturesWebSocket {
    /// The settings of a ``MexcFuturesWebSocket``.
    ///
    /// ## Compression
    ///
    /// Compression is off by default. MEXC pushes small, frequent messages, so decompressing each
    /// one costs more latency than it saves bandwidth.
    ///
    /// - Transport compression, the permessage-deflate extension of RFC 7692, is never used.
    ///   WebSocketKit and SwiftNIO do not implement the extension, so the handshake never offers it
    ///   and frames always arrive uncompressed.
    /// - Payload gzip is never requested. ``MexcFuturesWebSocket/subscribeToAllTickers()`` asks MEXC
    ///   for plain JSON.
    /// - Order book merging is chosen per subscription with
    ///   ``MexcFuturesWebSocket/subscribeToDepth(symbol:compress:)``, which asks for every change by default.
    public struct Configuration: Sendable {
        /// The URL of the futures WebSocket API.
        public var url: URL

        /// Whether the socket reconnects after the connection drops.
        ///
        /// After reconnecting, the socket logs in again, re-applies the personal filter
        /// and re-subscribes to market data.
        public var autoReconnect: Bool

        /// The delay before each reconnection attempt.
        public var reconnectInterval: Duration

        /// The interval between keep-alive pings, recommended between 10 and 20 seconds.
        public var pingInterval: Duration

        /// How long ``MexcFuturesWebSocket/connect()`` and a login wait for the server before they fail.
        public var timeout: Duration

        /// Creates the settings of a ``MexcFuturesWebSocket``.
        public init(
            url: URL = URL(string: "wss://contract.mexc.com/edge")!,
            autoReconnect: Bool = true,
            reconnectInterval: Duration = .seconds(5),
            pingInterval: Duration = .seconds(15),
            timeout: Duration = .seconds(10)
        ) {
            self.url = url
            self.autoReconnect = autoReconnect
            self.reconnectInterval = reconnectInterval
            self.pingInterval = pingInterval
            self.timeout = timeout
        }
    }
}
