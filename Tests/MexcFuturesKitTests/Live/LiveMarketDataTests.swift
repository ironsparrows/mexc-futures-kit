import Foundation
import SwiftyJSON
import Testing
import MexcFuturesKit

@Suite(
    "Live market data",
    .tags(.networking),
    .enabled(if: ProcessInfo.processInfo.environment["MEXC_LIVE_TESTS"] == "1", "Set MEXC_LIVE_TESTS=1 to reach MEXC")
)
struct LiveMarketDataTests {
    @Test func restReturnsTicker() async throws {
        let client = MexcFuturesClient()

        let ticker = try await client.ticker(symbol: "BTC_USDT")

        #expect(ticker["success"].boolValue)
        #expect(ticker["data"]["lastPrice"].doubleValue > 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func webSocketStreamsTicker() async throws {
        let socket = MexcFuturesWebSocket(configuration: .init(autoReconnect: false))
        let events = socket.events()
        try await socket.connect()
        try await socket.subscribeToTicker(symbol: "BTC_USDT")

        var subscribed = false
        for await event in events {
            switch event {
            case .subscribed(let channel, _):
                subscribed = channel == "ticker"
            case .ticker(let ticker):
                #expect(subscribed)
                #expect(ticker["symbol"].string == "BTC_USDT")
                await socket.disconnect()
                #expect(await socket.isConnected == false)
                return
            default:
                continue
            }
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func webSocketAnswersPing() async throws {
        let socket = MexcFuturesWebSocket(configuration: .init(autoReconnect: false, pingInterval: .seconds(1)))
        let events = socket.events()
        try await socket.connect()

        for await event in events {
            if case .pong(let timestamp) = event {
                #expect(timestamp.int64Value > 0)
                break
            }
        }
        await socket.disconnect()
    }

    @Test(.timeLimit(.minutes(1)))
    func disconnectDeliversDisconnected() async throws {
        let socket = MexcFuturesWebSocket()
        let events = socket.events()
        try await socket.connect()

        await socket.disconnect()

        for await event in events {
            if case .disconnected = event {
                break
            }
        }
        #expect(await socket.isConnected == false)
    }
}
