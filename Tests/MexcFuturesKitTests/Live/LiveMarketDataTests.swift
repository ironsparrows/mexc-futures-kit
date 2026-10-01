import Foundation
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

        let ticker = try await client.ticker(symbol: "BTC_USDT").get()

        #expect(ticker.symbol == "BTC_USDT")
        #expect(ticker.lastPrice > 0)
        #expect(ticker.timestamp.timeIntervalSinceNow > -60)
    }

    @Test func restReturnsContractDetail() async throws {
        let client = MexcFuturesClient()

        let single = try await client.contractDetail(symbol: "BTC_USDT").get()
        let all = try await client.contractDetail().get()

        #expect(single.map(\.symbol) == ["BTC_USDT"])
        #expect(single.first?.maxLeverage ?? 0 > 0)
        #expect(single.first?.state == .enabled)
        #expect(all.count > 100)
    }

    @Test func restReturnsOrderBook() async throws {
        let depth = try await MexcFuturesClient().contractDepth(symbol: "BTC_USDT", limit: 5).get()

        #expect(depth.asks.count == 5)
        #expect(depth.bids.count == 5)
        #expect(depth.asks[0].price > depth.bids[0].price)
        #expect(depth.version > 0)
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
                #expect(ticker.symbol == "BTC_USDT")
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
            if case .pong(let serverTime) = event {
                #expect(serverTime.timeIntervalSinceNow > -60)
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
