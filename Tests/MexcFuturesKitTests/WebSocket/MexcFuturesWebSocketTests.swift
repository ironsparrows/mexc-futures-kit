import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesWebSocket")
struct MexcFuturesWebSocketTests {
    let socket = MexcFuturesWebSocket()

    @Test func startsDisconnected() async {
        #expect(await socket.isConnected == false)
        #expect(await socket.isLoggedIn == false)
    }

    @Test func loginRequiresConnection() async {
        let error = await #expect(throws: MexcFuturesError.self) {
            try await socket.login(apiKey: "api-key", secretKey: "secret-key")
        }

        guard case .notConnected = error else {
            Issue.record("Expected notConnected, got \(String(describing: error))")
            return
        }
    }

    @Test func subscriptionRequiresConnection() async {
        let error = await #expect(throws: MexcFuturesError.self) {
            try await socket.subscribeToTicker(symbol: "BTC_USDT")
        }

        guard case .notConnected = error else {
            Issue.record("Expected notConnected, got \(String(describing: error))")
            return
        }
    }

    @Test func personalFilterRequiresLogin() async {
        let error = await #expect(throws: MexcFuturesError.self) {
            try await MexcFuturesWebSocket.Account(socket: socket).subscribeToOrders(symbols: ["BTC_USDT"])
        }

        guard case .notLoggedIn = error else {
            Issue.record("Expected notLoggedIn, got \(String(describing: error))")
            return
        }
    }
}
