import Foundation
import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesWebSocket reconnect", .tags(.networking), .timeLimit(.minutes(1)))
struct MexcFuturesWebSocketReconnectTests {
    let reconnecting: (URL) -> MexcFuturesWebSocket.Configuration = {
        .init(url: $0, autoReconnect: true, reconnectInterval: .milliseconds(50))
    }

    @Test func reconnectRestoresLoginFilterAndSubscriptions() async throws {
        try await withConnectedSocket(configuration: reconnecting) { server, socket, events in
            let account = try await socket.login(apiKey: "api-key", secretKey: "secret-key", subscribe: false)
            try await account.subscribeToPositions(symbols: ["BTC_USDT"])
            try await socket.subscribeToTicker(symbol: "BTC_USDT")
            try await socket.subscribeToKline(symbol: "ETH_USDT", interval: .fiveMinutes)
            _ = await server.methods(until: ["sub.kline"])

            await server.dropConnections()

            let restored = await server.methods(until: ["login", "personal.filter", "sub.ticker", "sub.kline"])
            let loginIndex = try #require(restored.firstIndex(of: "login"))
            let filterIndex = try #require(restored.firstIndex(of: "personal.filter"))
            #expect(loginIndex < filterIndex)
            #expect(await events.reconnected())
            #expect(await socket.isLoggedIn)
        }
    }

    @Test func unsubscribedChannelIsNotRestored() async throws {
        try await withConnectedSocket(configuration: reconnecting) { server, socket, events in
            try await socket.subscribeToTicker(symbol: "BTC_USDT")
            try await socket.unsubscribeFromTicker(symbol: "BTC_USDT")
            _ = await server.methods(until: ["unsub.ticker"])

            await server.dropConnections()
            #expect(await events.reconnected())
            try await socket.subscribeToDeals(symbol: "BTC_USDT")

            #expect(await server.methods(until: ["sub.deal"]) == ["sub.deal"])
        }
    }

    @Test func disconnectForgetsSession() async throws {
        try await withConnectedSocket(configuration: reconnecting) { server, socket, _ in
            try await socket.login(apiKey: "api-key", secretKey: "secret-key")
            try await socket.subscribeToTicker(symbol: "BTC_USDT")
            _ = await server.methods(until: ["sub.ticker"])

            await socket.disconnect()
            try await socket.connect()
            try await socket.subscribeToDeals(symbol: "BTC_USDT")

            #expect(await server.methods(until: ["sub.deal"]) == ["sub.deal"])
            #expect(await socket.isLoggedIn == false)
        }
    }
}

private extension AsyncStream<MexcFuturesWebSocket.Event> {
    func reconnected() async -> Bool {
        var sawDisconnect = false
        for await event in self {
            switch event {
            case .disconnected:
                sawDisconnect = true
            case .connected where sawDisconnect:
                return true
            default:
                continue
            }
        }
        return false
    }
}
