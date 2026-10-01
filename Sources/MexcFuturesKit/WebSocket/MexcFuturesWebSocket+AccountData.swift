import Foundation
import SwiftyJSON

extension MexcFuturesWebSocket {
    /// Logs in with the configured API key to receive private data.
    ///
    /// The ``Event/login(_:)`` event confirms the login, after which ``isLoggedIn`` is `true`.
    ///
    /// - Parameter subscribe: Whether the server pushes every kind of private data after login.
    ///   Pass `false` to choose the data with ``setPersonalFilter(_:)``.
    public func login(subscribe: Bool = true) async throws(MexcFuturesError) {
        guard isConnected else { throw .notConnected }
        let requestTime = String(Date.now.millisecondsSince1970)
        try await send([
            "subscribe": subscribe,
            "method": "login",
            "param": [
                "apiKey": configuration.apiKey,
                "signature": hmacSHA256(configuration.apiKey + requestTime, secret: configuration.secretKey),
                "reqTime": requestTime,
            ],
        ])
    }

    /// Selects the private data the server pushes.
    ///
    /// - Parameter filters: The kinds of private data to receive, or an empty array for every kind.
    public func setPersonalFilter(_ filters: [PersonalFilter] = []) async throws(MexcFuturesError) {
        guard isLoggedIn else { throw .notLoggedIn }
        try await send(["method": "personal.filter", "param": ["filters": filters.map(\.json)]])
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
