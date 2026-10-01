import Foundation
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

    @Test func tokenLoginSendsTokenOnly() async throws {
        try await withConnectedSocket { server, socket, _ in
            try await socket.login(authToken: "WEB-token", subscribe: false)

            let login = try #require(await server.nextMessage(method: "login"))
            #expect(login["param"]["token"].string == "WEB-token")
            #expect(login["param"]["signature"].exists == false)
            #expect(login["subscribe"].bool == false)
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
            #expect(filter["param"]["filters"].description == #"[{"filter":"order","rules":["BTC_USDT"]},{"filter":"asset"}]"#)
        }
    }

    @Test func everyStreamReceivesPushedData() async throws {
        try await withConnectedSocket { server, socket, events in
            let second = socket.events()

            try await server.send(["channel": "push.ticker", "data": ["symbol": "BTC_USDT"]])

            for stream in [events, second] {
                let ticker = await stream.compactMap { $0.caseName == "ticker" ? $0.payload : nil }.first { _ in true }
                #expect(ticker?["symbol"].string == "BTC_USDT")
            }
        }
    }

    @Test func handlerReceivesPushedData() async throws {
        try await withConnectedSocket { server, socket, _ in
            let (tickers, continuation) = AsyncStream.makeStream(of: JSON.self)
            socket.onEvent { event in
                if case .ticker(let ticker) = event {
                    continuation.yield(ticker)
                }
            }

            try await server.send(["channel": "push.ticker", "data": ["symbol": "BTC_USDT"]])

            #expect(await tickers.first { _ in true }?["symbol"].string == "BTC_USDT")
        }
    }

    @Test func malformedMessageDeliversErrorAndKeepsConnection() async throws {
        try await withConnectedSocket { server, socket, events in
            try await server.send(text: "not json")

            let error = await events.compactMap { event -> MexcFuturesError? in
                if case .error(let error) = event { error } else { nil }
            }.first { _ in true }
            guard case .malformedMessage = error else {
                Issue.record("Expected a malformed message error, got \(String(describing: error))")
                return
            }
            #expect(await socket.isConnected)
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
