import Foundation
import SwiftyJSON

extension MexcFuturesWebSocket {
    /// The private account data of a logged-in ``MexcFuturesWebSocket``.
    ///
    /// Get an account from ``MexcFuturesWebSocket/login(apiKey:secretKey:subscribe:)``. Account events,
    /// such as ``MexcFuturesWebSocket/Event/orderUpdate(_:)``, arrive on the socket's ``MexcFuturesWebSocket/events(bufferingPolicy:)``.
    ///
    /// ```swift
    /// let account = try await socket.login(apiKey: "...", secretKey: "...", subscribe: false)
    /// try await account.subscribeToOrders(symbols: ["BTC_USDT"])
    /// ```
    public struct Account: Sendable {
        /// The socket that delivers the account's events.
        public let socket: MexcFuturesWebSocket

        /// Selects the private data the server pushes.
        ///
        /// - Parameter filters: The kinds of private data to receive, or an empty array for every kind.
        /// - Throws: ``MexcFuturesError/notLoggedIn`` when the socket is no longer logged in.
        public func setPersonalFilter(_ filters: [PersonalFilter] = []) async throws(MexcFuturesError) {
            try await socket.setPersonalFilter(filters)
        }

        /// Receives only order updates.
        ///
        /// - Parameter symbols: The contract symbols to receive updates for, or `nil` for every contract.
        public func subscribeToOrders(symbols: [String]? = nil) async throws(MexcFuturesError) {
            try await setPersonalFilter([PersonalFilter(.order, symbols: symbols)])
        }

        /// Receives only order executions.
        ///
        /// - Parameter symbols: The contract symbols to receive executions for, or `nil` for every contract.
        public func subscribeToOrderDeals(symbols: [String]? = nil) async throws(MexcFuturesError) {
            try await setPersonalFilter([PersonalFilter(.orderDeal, symbols: symbols)])
        }

        /// Receives only position updates.
        ///
        /// - Parameter symbols: The contract symbols to receive updates for, or `nil` for every contract.
        public func subscribeToPositions(symbols: [String]? = nil) async throws(MexcFuturesError) {
            try await setPersonalFilter([PersonalFilter(.position, symbols: symbols)])
        }

        /// Receives only balance updates.
        public func subscribeToAssets() async throws(MexcFuturesError) {
            try await setPersonalFilter([PersonalFilter(.asset)])
        }

        /// Receives only auto-deleveraging level updates.
        public func subscribeToADLLevels() async throws(MexcFuturesError) {
            try await setPersonalFilter([PersonalFilter(.adlLevel)])
        }

        /// Receives every kind of private data.
        public func subscribeToAll() async throws(MexcFuturesError) {
            try await setPersonalFilter([])
        }
    }

    /// Logs in to receive private account data, and waits for the server to accept the login.
    ///
    /// Market data needs no login. After the login, ``isLoggedIn`` is `true`.
    ///
    /// - Parameters:
    ///   - apiKey: The API key created in MEXC API management.
    ///   - secretKey: The secret key paired with `apiKey`, used to sign the login.
    ///   - subscribe: Whether the server pushes every kind of private data after login.
    ///     Pass `false` to choose the data with ``Account/setPersonalFilter(_:)``.
    /// - Returns: The account, which selects the private data the server pushes.
    /// - Throws: ``MexcFuturesError/authentication(message:)`` when the server rejects the login.
    @discardableResult
    public func login(apiKey: String, secretKey: String, subscribe: Bool = true) async throws(MexcFuturesError) -> Account {
        guard isConnected else { throw .notConnected }
        let responses = events()
        let requestTime = String(Date.now.millisecondsSince1970)
        try await send([
            "subscribe": subscribe,
            "method": "login",
            "param": [
                "apiKey": apiKey,
                "signature": hmacSHA256(apiKey + requestTime, secret: secretKey),
                "reqTime": requestTime,
            ],
        ])

        for await event in responses {
            switch event {
            case .login:
                return Account(socket: self)
            case .loginFailed(let response):
                throw .authentication(message: response["msg"].string ?? response.string ?? response.rawString(options: []) ?? "Login rejected")
            case .disconnected:
                throw .notConnected
            default:
                continue
            }
        }
        throw Task.isCancelled ? .cancelled : .notConnected
    }

    func setPersonalFilter(_ filters: [PersonalFilter]) async throws(MexcFuturesError) {
        guard isLoggedIn else { throw .notLoggedIn }
        try await send(["method": "personal.filter", "param": ["filters": filters.map(\.json)]])
    }
}
