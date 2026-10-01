import Foundation
import NIOHTTP1
import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesWebSocket compression", .tags(.networking), .timeLimit(.minutes(1)))
struct MexcFuturesWebSocketCompressionTests {
    @Test func handshakeNeverOffersPerMessageDeflate() async throws {
        try await withConnectedSocket { server, _, _ in
            let handshake = try #require(server.handshakes.first)

            #expect(handshake["Sec-WebSocket-Extensions"].isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func depthSubscriptionSendsMergeChoice(merged: Bool) async throws {
        try await withConnectedSocket { server, socket, _ in
            try await socket.subscribeToDepth(symbol: "BTC_USDT", merged: merged)

            let subscription = await server.nextMessage(method: "sub.depth")
            #expect(subscription == ["method": "sub.depth", "param": ["symbol": "BTC_USDT", "compress": merged], "gzip": false])
        }
    }

    @Test(arguments: [false, true])
    func subscriptionsRequestConfiguredPayloadEncoding(gzipPayloads: Bool) async throws {
        try await withConnectedSocket(configuration: { .init(url: $0, autoReconnect: false, gzipPayloads: gzipPayloads) }) { server, socket, _ in
            try await socket.subscribeToAllTickers()

            let subscription = await server.nextMessage(method: "sub.tickers")
            #expect(subscription == ["method": "sub.tickers", "param": [:], "gzip": JSON(gzipPayloads)])
        }
    }

    @Test func gzipPayloadDecodesLikeItsPlainTwin() async throws {
        try await withConnectedSocket(configuration: { .init(url: $0, autoReconnect: false, gzipPayloads: true) }) { server, _, events in
            try await server.send(binary: [UInt8](GzipFixtures.gzippedTicker))
            try await server.send(JSON(parseJSON: GzipFixtures.plainTicker))

            let tickers = await events.compactMap { $0.caseName == "ticker" ? $0.payload : nil }.prefix(2).reduce(into: []) { $0.append($1) }
            #expect(tickers.count == 2)
            #expect(tickers.first == tickers.last)
            #expect(tickers.first?["lastPrice"].double == 83500.5)
        }
    }

    @Test func unexpectedBinaryFrameReportsErrorAndKeepsConnection() async throws {
        try await withConnectedSocket { server, socket, events in
            try await server.send(binary: [UInt8](GzipFixtures.gzippedTicker))

            let error = await events.compactMap { event -> MexcFuturesError? in
                if case .error(let error) = event { error } else { nil }
            }.first { _ in true }
            guard case .unexpectedBinaryFrame(let byteCount) = error else {
                Issue.record("Expected an unexpected binary frame error, got \(String(describing: error))")
                return
            }
            #expect(byteCount == GzipFixtures.gzippedTicker.count)
            #expect(await socket.isConnected)
        }
    }

    @Test func corruptGzipPayloadReportsMalformedMessage() async throws {
        try await withConnectedSocket(configuration: { .init(url: $0, autoReconnect: false, gzipPayloads: true) }) { server, _, events in
            try await server.send(binary: [0x1f, 0x8b, 0x08, 0x00, 0x01, 0x02])

            let error = await events.compactMap { event -> MexcFuturesError? in
                if case .error(let error) = event { error } else { nil }
            }.first { _ in true }
            guard case .malformedMessage = error else {
                Issue.record("Expected a malformed message error, got \(String(describing: error))")
                return
            }
        }
    }
}
