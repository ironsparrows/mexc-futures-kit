import Foundation
import Logging
import SwiftyJSON

extension MexcFuturesWebSocket {
    struct Session {
        var credentials: Credentials?
        var personalFilters: [PersonalFilter]?
        var subscriptions: [MarketSubscription: JSON] = [:]
    }

    struct Credentials {
        let apiKey: String
        let secretKey: String
        let subscribe: Bool
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
        variant: String? = nil
    ) async throws(MexcFuturesError) {
        var parameters = parameters
        if let symbol {
            parameters["symbol"] = symbol
        }
        let message: JSON = ["method": "sub.\(channel)", "param": parameters, "gzip": configuration.gzipPayloads]
        try await send(message)
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
