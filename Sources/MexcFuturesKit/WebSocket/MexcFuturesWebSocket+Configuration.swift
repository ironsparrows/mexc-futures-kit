extension MexcFuturesWebSocket {
    /// The settings of a ``MexcFuturesWebSocket``.
    public struct Configuration: Sendable {
        /// Whether the socket reconnects after the connection drops.
        public var autoReconnect: Bool

        /// The delay before each reconnection attempt.
        public var reconnectInterval: Duration

        /// The interval between keep-alive pings, recommended between 10 and 20 seconds.
        public var pingInterval: Duration

        /// Creates the settings of a ``MexcFuturesWebSocket``.
        public init(
            autoReconnect: Bool = true,
            reconnectInterval: Duration = .seconds(5),
            pingInterval: Duration = .seconds(15)
        ) {
            self.autoReconnect = autoReconnect
            self.reconnectInterval = reconnectInterval
            self.pingInterval = pingInterval
        }
    }
}
