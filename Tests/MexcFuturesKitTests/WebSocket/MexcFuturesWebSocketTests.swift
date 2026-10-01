import SwiftyJSON
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

    @Test func loginAcknowledgementLogsIn() async throws {
        var events = socket.events().makeAsyncIterator()

        await socket.receive(#"{"channel":"rs.login","data":"success"}"#)

        #expect(await socket.isLoggedIn)
        #expect(await events.next()?.caseName == "login")
    }

    @Test func loginRejectionLogsOut() async {
        await socket.receive(#"{"channel":"rs.login","data":"success"}"#)

        await socket.receive(#"{"channel":"rs.login","data":{"code":1}}"#)

        #expect(await socket.isLoggedIn == false)
    }

    @Test func malformedMessageDeliversError() async throws {
        var events = socket.events().makeAsyncIterator()

        await socket.receive("not json")

        let event = try #require(await events.next())
        guard case .error(.malformedMessage(let text)) = event else {
            Issue.record("Expected a malformed message error, got \(event)")
            return
        }
        #expect(text == "not json")
    }

    @Test func everyStreamReceivesEveryEvent() async {
        var first = socket.events().makeAsyncIterator()
        var second = socket.events().makeAsyncIterator()

        await socket.receive(#"{"channel":"push.ticker","data":{"symbol":"BTC_USDT"}}"#)

        #expect(await first.next()?.payload?["symbol"].string == "BTC_USDT")
        #expect(await second.next()?.payload?["symbol"].string == "BTC_USDT")
    }
}
