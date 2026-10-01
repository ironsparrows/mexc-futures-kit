extension MexcFuturesWebSocket {
    /// The settings of a ``MexcFuturesWebSocket``.
    public struct Configuration: Sendable {
        /// The API key created in MEXC API management.
        public var apiKey: String

        /// The secret key paired with ``apiKey``, used to sign the login.
        public var secretKey: String

        /// Whether the socket reconnects after the connection drops.
        public var autoReconnect: Bool

        /// The delay before each reconnection attempt.
        public var reconnectInterval: Duration

        /// The interval between keep-alive pings, recommended between 10 and 20 seconds.
        public var pingInterval: Duration

        /// Creates the settings of a ``MexcFuturesWebSocket``.
        public init(
            apiKey: String,
            secretKey: String,
            autoReconnect: Bool = true,
            reconnectInterval: Duration = .seconds(5),
            pingInterval: Duration = .seconds(15)
        ) {
            self.apiKey = apiKey
            self.secretKey = secretKey
            self.autoReconnect = autoReconnect
            self.reconnectInterval = reconnectInterval
            self.pingInterval = pingInterval
        }
    }
}
