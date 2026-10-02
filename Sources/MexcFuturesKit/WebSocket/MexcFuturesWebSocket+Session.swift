import Foundation
import Logging

extension MexcFuturesWebSocket {
    struct Session {
        let id = UUID()
        var credentials: Credentials?
        var personalFilters: [PersonalFilter]?
        var subscriptions: [MarketSubscription: [String: Any]] = [:]
    }

    struct Credentials {
        enum Key {
            case authToken(String)
            case apiKey(String, secretKey: String)
        }

        let key: Key
        let subscribe: Bool

        var loginParameters: [String: String] {
            switch key {
            case .authToken(let token):
                return ["token": token]
            case .apiKey(let apiKey, let secretKey):
                let requestTime = String(Date.now.millisecondsSince1970)
                return ["apiKey": apiKey, "signature": hmacSHA256(apiKey + requestTime, secret: secretKey), "reqTime": requestTime]
            }
        }
    }

    struct MarketSubscription: Hashable {
        let channel: String
        let symbol: String?
        let variant: String?
    }

    func subscribe(
        to channel: String,
        symbol: String? = nil,
        parameters: [String: Any] = [:],
        variant: String? = nil,
        gzip: Bool? = nil
    ) async throws(MexcFuturesError) {
        var parameters = parameters
        if let symbol {
            parameters["symbol"] = symbol
        }
        var message: [String: Any] = ["method": "sub.\(channel)", "param": parameters]
        if let gzip {
            message["gzip"] = gzip
        }
        let sessionID = session.id
        try await send(message)
        guard session.id == sessionID else { throw .notConnected }
        session.subscriptions[MarketSubscription(channel: channel, symbol: symbol, variant: variant)] = message
    }

    func unsubscribe(from channel: String, symbol: String? = nil) async throws(MexcFuturesError) {
        try await send(["method": "unsub.\(channel)", "param": symbol.map { ["symbol": $0] } ?? [String: String]()])
        session.subscriptions = session.subscriptions.filter { $0.key.channel != channel || $0.key.symbol != symbol }
    }

    func restoreSession() async {
        if let credentials = session.credentials {
            do {
                try await authenticate(credentials)
                if let personalFilters = session.personalFilters {
                    try await setPersonalFilter(personalFilters)
                }
            } catch {
                logger.warning("WebSocket login could not be restored", metadata: ["error": "\(error.localizedDescription)"])
                broadcaster.yield(.error(error))
            }
        }
        for message in session.subscriptions.values {
            do {
                try await send(message)
            } catch {
                logger.warning("WebSocket subscription could not be restored", metadata: ["error": "\(error.localizedDescription)"])
                return
            }
        }
    }
}
