import Foundation
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
        let event = MexcFuturesWebSocket.Event(channel: channel, data: ["value": 42])

        #expect(event.caseName == expectedCase)
        #expect(event.payload?["value"].int == 42)
    }

    @Test(arguments: [JSON(serializing: "success"), JSON(serializing: ["code": 0])])
    func loginAcknowledgementDeliversMessage(data: JSON) {
        let event = MexcFuturesWebSocket.Event(channel: "rs.login", data: data)

        #expect(event.caseName == "login")
        #expect(event.payload?["channel"].string == "rs.login")
    }

    @Test func loginRejectionDeliversData() {
        let event = MexcFuturesWebSocket.Event(channel: "rs.login", data: ["code": 401, "msg": "denied"])

        #expect(event.caseName == "loginFailed")
        #expect(event.payload?["msg"].string == "denied")
    }

    @Test(arguments: [
        (JSON(serializing: "success"), "filterSet"),
        (JSON(serializing: ["code": 0]), "filterSet"),
        (JSON(serializing: "failed"), "filterFailed"),
    ])
    func filterResponseReportsOutcome(data: JSON, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(channel: "rs.personal.filter", data: data)

        #expect(event.caseName == expectedCase)
    }

    @Test(arguments: [
        ("rs.sub.depth.full", "subscribed"),
        ("rs.unsub.depth.full", "unsubscribed"),
    ])
    func subscriptionResponseNamesChannel(channel: String, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(channel: channel, data: "success")

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
        let event = MexcFuturesWebSocket.Event(channel: "rs.error", data: "invalid param")

        guard case .error(.server(let message)) = event else {
            Issue.record("Expected a server error, got \(event)")
            return
        }
        #expect(message == "invalid param")
    }

    @Test func malformedTextDeliversError() {
        let event = MexcFuturesWebSocket.Event(text: "not json")

        guard case .error(.malformedMessage(let text)) = event else {
            Issue.record("Expected a malformed message error, got \(event)")
            return
        }
        #expect(text == "not json")
    }

    @Test func unknownChannelDeliversMessage() {
        let event = MexcFuturesWebSocket.Event(channel: "push.unknown", data: 1)

        #expect(event.caseName == "message")
        #expect(event.payload?["channel"].string == "push.unknown")
    }
}

extension MexcFuturesWebSocket.Event {
    init(channel: String, data: Any) {
        let data = data as? JSON ?? JSON(serializing: data)
        self.init(text: #"{"channel":"\#(channel)","data":\#(data),"ts":1}"#)
    }

    var caseName: String {
        Mirror(reflecting: self).children.first?.label ?? String(describing: self)
    }

    var payload: JSON? {
        Mirror(reflecting: self).children.first?.value as? JSON
    }
}
