import SwiftyJSON
import Testing
@testable import MexcFuturesKit

@Suite("WebSocket event routing")
struct EventTests {
    @Test(arguments: [
        ("pong", "pong"),
        ("push.tickers", "tickers"),
        ("push.ticker", "ticker"),
        ("push.deal", "deal"),
        ("push.depth", "depth"),
        ("push.kline", "kline"),
        ("push.funding.rate", "fundingRate"),
        ("push.index.price", "indexPrice"),
        ("push.fair.price", "fairPrice"),
        ("push.personal.order", "orderUpdate"),
        ("push.personal.order.deal", "orderDeal"),
        ("push.personal.position", "positionUpdate"),
        ("push.personal.asset", "assetUpdate"),
        ("push.personal.stop.order", "stopOrder"),
        ("push.personal.stop.planorder", "stopPlanOrder"),
        ("push.personal.liquidate.risk", "liquidateRisk"),
        ("push.personal.adl.level", "adlLevel"),
        ("push.personal.risk.limit", "riskLimit"),
        ("push.personal.plan.order", "planOrder"),
    ])
    func pushChannelDeliversData(channel: String, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(message: ["channel": channel, "data": ["value": 42], "ts": 1])

        #expect(event.caseName == expectedCase)
        #expect(event.payload?["value"].int == 42)
    }

    @Test(arguments: [JSON("success"), JSON(["code": 0])])
    func loginAcknowledgementDeliversMessage(data: JSON) {
        let event = MexcFuturesWebSocket.Event(message: ["channel": "rs.login", "data": data])

        #expect(event.caseName == "login")
        #expect(event.payload?["channel"].string == "rs.login")
    }

    @Test func loginRejectionDeliversData() {
        let event = MexcFuturesWebSocket.Event(message: ["channel": "rs.login", "data": ["code": 401, "msg": "denied"]])

        #expect(event.caseName == "loginFailed")
        #expect(event.payload?["msg"].string == "denied")
    }

    @Test(arguments: [
        (JSON("success"), "filterSet"),
        (JSON(["code": 0]), "filterSet"),
        (JSON("failed"), "filterFailed"),
    ])
    func filterResponseReportsOutcome(data: JSON, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(message: ["channel": "rs.personal.filter", "data": data])

        #expect(event.caseName == expectedCase)
    }

    @Test(arguments: [
        ("rs.sub.depth.full", "subscribed"),
        ("rs.unsub.depth.full", "unsubscribed"),
    ])
    func subscriptionResponseNamesChannel(channel: String, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(message: ["channel": channel, "data": "success"])

        switch event {
        case .subscribed(let channel, let data) where expectedCase == "subscribed",
             .unsubscribed(let channel, let data) where expectedCase == "unsubscribed":
            #expect(channel == "depth.full")
            #expect(data.string == "success")
        default:
            Issue.record("Expected \(expectedCase), got \(event)")
        }
    }

    @Test func errorChannelDeliversServerError() {
        let event = MexcFuturesWebSocket.Event(message: ["channel": "rs.error", "data": "invalid param"])

        guard case .error(.server(let message)) = event else {
            Issue.record("Expected a server error, got \(event)")
            return
        }
        #expect(message == "invalid param")
    }

    @Test func unknownChannelDeliversMessage() {
        let event = MexcFuturesWebSocket.Event(message: ["channel": "push.unknown", "data": 1])

        #expect(event.caseName == "message")
        #expect(event.payload?["channel"].string == "push.unknown")
    }
}

extension MexcFuturesWebSocket.Event {
    var caseName: String {
        Mirror(reflecting: self).children.first?.label ?? String(describing: self)
    }

    var payload: JSON? {
        Mirror(reflecting: self).children.first?.value as? JSON
    }
}
