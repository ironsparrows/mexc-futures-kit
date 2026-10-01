import Foundation
import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesWebSocket connection", .tags(.networking), .timeLimit(.minutes(1)))
struct MexcFuturesWebSocketConnectionTests {
    @Test func connectDeliversConnectedEvent() async throws {
        try await withConnectedSocket { _, socket, events in
            #expect(await socket.isConnected)
            #expect(await events.first { _ in true }?.caseName == "connected")
        }
    }

    @Test func loginSendsSignedCredentialsAndReturnsAccount() async throws {
        try await withConnectedSocket { server, socket, _ in
            try await socket.login(apiKey: "api-key", secretKey: "secret-key", subscribe: false)

            let login = try #require(await server.nextMessage(method: "login"))
            let requestTime = login["param"]["reqTime"].stringValue
            #expect(login["subscribe"].bool == false)
            #expect(login["param"]["apiKey"].string == "api-key")
            #expect(login["param"]["signature"].string == hmacSHA256("api-key" + requestTime, secret: "secret-key"))
            #expect(await socket.isLoggedIn)
        }
    }

    @Test func rejectedLoginThrowsAuthentication() async throws {
        try await withConnectedSocket(behavior: .init(acceptsLogin: false)) { _, socket, _ in
            let error = await #expect(throws: MexcFuturesError.self) {
                try await socket.login(apiKey: "api-key", secretKey: "wrong")
            }

            guard case .authentication(let message) = error else {
                Issue.record("Expected an authentication error, got \(String(describing: error))")
                return
            }
            #expect(message == "failed")
            #expect(await socket.isLoggedIn == false)
        }
    }

    @Test func accountSendsPersonalFilter() async throws {
        try await withConnectedSocket { server, socket, _ in
            let account = try await socket.login(apiKey: "api-key", secretKey: "secret-key", subscribe: false)

            try await account.setPersonalFilter([PersonalFilter(.order, symbols: ["BTC_USDT"]), PersonalFilter(.asset)])

            let filter = try #require(await server.nextMessage(method: "personal.filter"))
            #expect(filter["param"]["filters"] == [["filter": "order", "rules": ["BTC_USDT"]], ["filter": "asset"]])
        }
    }

    @Test func marketSubscriptionNeedsNoLogin() async throws {
        try await withConnectedSocket { server, socket, _ in
            try await socket.subscribeToTicker(symbol: "BTC_USDT")

            let subscription = try #require(await server.nextMessage(method: "sub.ticker"))
            #expect(subscription["param"]["symbol"].string == "BTC_USDT")
            #expect(await socket.isLoggedIn == false)
        }
    }
}

func withConnectedSocket(
    behavior: MockMexcServer.Behavior = .init(),
    configuration: (URL) -> MexcFuturesWebSocket.Configuration = { .init(url: $0, autoReconnect: false) },
    _ body: (MockMexcServer, MexcFuturesWebSocket, AsyncStream<MexcFuturesWebSocket.Event>) async throws -> Void
) async throws {
    let server = try await MockMexcServer.start(behavior: behavior)
    let socket = MexcFuturesWebSocket(configuration: configuration(server.url))
    let events = socket.events()
    do {
        try await socket.connect()
        try await body(server, socket, events)
    } catch {
        await socket.disconnect()
        await server.shutdown()
        throw error
    }
    await socket.disconnect()
    await server.shutdown()
}
