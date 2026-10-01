public import Foundation

extension MexcFuturesWebSocket {
    /// The settings of a ``MexcFuturesWebSocket``.
    public struct Configuration: Sendable {
        /// The URL of the futures WebSocket API.
        public var url: URL

        /// Whether the socket reconnects after the connection drops.
        public var autoReconnect: Bool

        /// The delay before each reconnection attempt.
        public var reconnectInterval: Duration

        /// The interval between keep-alive pings, recommended between 10 and 20 seconds.
        public var pingInterval: Duration

        /// Creates the settings of a ``MexcFuturesWebSocket``.
        public init(
            url: URL = URL(string: "wss://contract.mexc.com/edge")!,
            autoReconnect: Bool = true,
            reconnectInterval: Duration = .seconds(5),
            pingInterval: Duration = .seconds(15)
        ) {
            self.url = url
            self.autoReconnect = autoReconnect
            self.reconnectInterval = reconnectInterval
            self.pingInterval = pingInterval
        }
    }
}
