public import Foundation

extension MexcFuturesWebSocket {
    /// The settings of a ``MexcFuturesWebSocket``.
    ///
    /// Settings are fixed for the life of a socket. To change them, create a new socket.
    ///
    /// ## Compression
    ///
    /// Every kind of compression is off by default. MEXC pushes small, frequent messages, so
    /// decompressing each one costs more latency than it saves bandwidth.
    ///
    /// - Transport compression, the permessage-deflate extension of RFC 7692, is never used.
    ///   WebSocketKit and SwiftNIO do not implement the extension, so the handshake never offers it
    ///   and frames always arrive uncompressed.
    /// - Payload compression is controlled by ``gzipPayloads``.
    /// - Order book merging is chosen per subscription with
    ///   ``MexcFuturesWebSocket/subscribeToDepth(symbol:merged:)``.
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

        /// Whether market data subscriptions ask MEXC to gzip the pushed data.
        ///
        /// When `false`, subscriptions ask for plain JSON text frames. When `true`, subscriptions ask
        /// for gzip, and the socket decompresses binary frames. A binary frame that arrives while this
        /// is `false` is delivered as ``MexcFuturesError/unexpectedBinaryFrame(byteCount:)``.
        public var gzipPayloads: Bool

        /// Creates the settings of a ``MexcFuturesWebSocket``.
        public init(
            url: URL = URL(string: "wss://contract.mexc.com/edge")!,
            autoReconnect: Bool = true,
            reconnectInterval: Duration = .seconds(5),
            pingInterval: Duration = .seconds(15),
            gzipPayloads: Bool = false
        ) {
            self.url = url
            self.autoReconnect = autoReconnect
            self.reconnectInterval = reconnectInterval
            self.pingInterval = pingInterval
            self.gzipPayloads = gzipPayloads
        }
    }
}
