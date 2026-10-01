import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("WebSocket event decoding")
struct EventTests {
    @Test func decodesTicker() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"symbol":"BTC_USDT","lastPrice":84055,"riseFallRate":-0.0005,"fairPrice":84063.8,"indexPrice":84104,"volume24":311051901,"amount24":2606920596.04,"maxBidPrice":92514.4,"minAskPrice":75693.6,"lower24Price":83136.6,"high24Price":84461.9,"timestamp":1790870036854,"bid1":84054.9,"ask1":84055,"holdVol":546882118,"riseFallValue":-47.2,"fundingRate":0.000072,"zone":"UTC+8","riseFallRates":[-0.0005,0.0011,0.0701,0.365,0.2581,-0.2565],"riseFallRatesOfTimezone":[0.0035,0.0057,-0.0005]},"channel":"push.ticker","ts":1790870036854}"#)

        guard case .ticker(let ticker) = event else { Issue.record("Expected a ticker, got \(event)"); return }
        #expect(ticker.contractID == nil)
        #expect(ticker.lastPrice == 84055)
        #expect(ticker.bid1 == 84054.9)
        #expect(ticker.riseFallRates == .init(zone: "UTC+8", rate: -0.0005, value: -47.2, rate7Days: 0.0011, rate30Days: 0.0701, rate90Days: 0.365, rate180Days: 0.2581, rate365Days: -0.2565))
    }

    @Test func decodesTickers() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.tickers","data":[{"amount24":157589.74,"contractId":1156,"fairPrice":0.04116,"high24Price":0.04297,"indexPrice":0.04119,"lastPrice":0.04114,"lower24Price":0.04068,"maxBidPrice":0.04942,"minAskPrice":0.03295,"riseFallRate":-0.0292,"symbol":"WCT_USDT","timestamp":1790870034312,"volume24":376505}],"ts":1790870034312}"#)

        guard case .tickers(let tickers) = event else { Issue.record("Expected tickers, got \(event)"); return }
        #expect(tickers.map(\.symbol) == ["WCT_USDT"])
        #expect(tickers.first?.contractID == 1156)
        #expect(tickers.first?.volume24 == 376505)
    }

    @Test func decodesDeals() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":[{"p":84062.6,"v":13,"T":1,"O":3,"M":1,"t":1790870038339,"i":"16435741160","cts":"1790870038339"}],"channel":"push.deal","ts":1790870038339}"#)

        guard case .deal(let symbol, let deals) = event else { Issue.record("Expected deals, got \(event)"); return }
        #expect(symbol == "BTC_USDT")
        #expect(deals == [Deal(id: 16435741160, price: 84062.6, volume: 13, side: .buy, timestamp: Date(timeIntervalSince1970: 1_790_870_038.339))])
    }

    @Test(arguments: ["push.depth", "push.depth.full"])
    func decodesOrderBook(channel: String) throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"cts":1790870038457,"asks":[[84062.6,60366,1]],"bids":[[84062.5,34991,8],[84062.4,61,1]],"version":42274310475},"channel":"\#(channel)","ts":1790870038460}"#)

        let (symbol, depth): (String, ContractDepth)
        switch event {
        case .depth(let s, let d) where channel == "push.depth", .fullDepth(let s, let d) where channel == "push.depth.full":
            (symbol, depth) = (s, d)
        default:
            Issue.record("Expected an order book for \(channel), got \(event)")
            return
        }
        #expect(symbol == "BTC_USDT")
        #expect(depth.asks == [.init(price: 84062.6, volume: 60366, orderCount: 1)])
        #expect(depth.bids.count == 2)
        #expect(depth.version == 42274310475)
        #expect(depth.timestamp == Date(timeIntervalSince1970: 1_790_870_038.457))
    }

    @Test func decodesKline() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"symbol":"BTC_USDT","interval":"Min1","t":1790869980,"o":84109.4,"c":84062.6,"h":84114.5,"l":84054,"a":1779128.94,"q":211601,"ro":84112,"rc":84062.6,"rh":84114.5,"rl":84054},"channel":"push.kline","ts":1790870038344}"#)

        guard case .kline(let kline) = event else { Issue.record("Expected a kline, got \(event)"); return }
        #expect(kline == Kline(symbol: "BTC_USDT", interval: .oneMinute, openTime: Date(timeIntervalSince1970: 1_790_869_980), open: 84109.4, close: 84062.6, high: 84114.5, low: 84054, amount: 1779128.94, volume: 211601))
    }

    @Test func decodesFundingAndReferencePrices() throws {
        let funding = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"symbol":"BTC_USDT","rate":0.000072,"nextSettleTime":1790870400000},"channel":"push.funding.rate","ts":1}"#)
        let index = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"symbol":"BTC_USDT","price":84105},"channel":"push.index.price","ts":1}"#)
        let fair = MexcFuturesWebSocket.Event(text: #"{"symbol":"BTC_USDT","data":{"symbol":"BTC_USDT","price":84064.5},"channel":"push.fair.price","ts":1}"#)

        guard case .fundingRate(let rate) = funding, case .indexPrice(let indexPrice) = index, case .fairPrice(let fairPrice) = fair else {
            Issue.record("Expected funding, index and fair price events")
            return
        }
        #expect(rate == FundingRate(symbol: "BTC_USDT", rate: 0.000072, nextSettleTime: Date(timeIntervalSince1970: 1_790_870_400)))
        #expect(indexPrice == ContractPrice(symbol: "BTC_USDT", price: 84105))
        #expect(fairPrice == ContractPrice(symbol: "BTC_USDT", price: 84064.5))
    }

    @Test func decodesOrderUpdate() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.order","data":{"bboTypeNum":0,"bizSource":1,"category":1,"createTime":1700000000000,"dealAvgPrice":0.2011,"dealVol":23,"errorCode":0,"externalOid":"_m_example","feeCurrency":"USDT","leverage":2,"makerFee":0,"makerFeeRate":0.0001,"openType":1,"orderId":"817027833053397504","orderMargin":2.3,"orderType":5,"positionId":1234567890,"positionMode":1,"positionType":"long","price":0.2011,"profit":0,"remainVol":0,"side":1,"sideType":"buy","state":3,"symbol":"ARB_USDT","takerFee":0.0018,"takerFeeRate":0.0004,"updateTime":1700000000100,"usedMargin":2.3,"version":2,"vol":23},"ts":1700000000100}"#)

        guard case .orderUpdate(let order) = event else { Issue.record("Expected an order update, got \(event)"); return }
        #expect(order.orderID == 817027833053397504)
        #expect(order.positionID == 1234567890)
        #expect(order.side == .openLong)
        #expect(order.orderType == .market)
        #expect(order.state == .completed)
        #expect(order.dealVolume == 23)
        #expect(order.positionMode == .hedge)
    }

    @Test func decodesOrderDeal() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.order.deal","data":{"category":1,"externalOid":"_m_example","fee":0.0018,"feeCurrency":"USDT","id":"13914408525","isSelf":false,"orderId":"817027833053397504","positionMode":1,"price":0.2011,"profit":0,"side":1,"symbol":"ARB_USDT","taker":true,"timestamp":1700000000000,"vol":23},"ts":1700000000000}"#)

        guard case .orderDeal(let deal) = event else { Issue.record("Expected an order deal, got \(event)"); return }
        #expect(deal.id == 13914408525)
        #expect(deal.orderID == 817027833053397504)
        #expect(deal.isTaker)
        #expect(deal.volume == 23)
    }

    @Test func decodesPositionUpdate() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.position","data":{"adlLevel":0,"autoAddIm":false,"closeAvgPrice":0,"closeProfitLoss":0,"closeVol":0,"createTime":1700000000000,"deductFeeList":[],"fee":-0.0018,"frozenVol":0,"holdAvgPrice":0.2011,"holdFee":0,"holdVol":23,"im":2.31,"leverage":2,"liquidatePrice":0.10127,"marginRatio":0.0079,"oim":2.31,"openAvgPrice":0.2011,"openType":1,"pnl":-0.8155,"positionId":1234567890,"positionType":1,"realised":-0.0018,"state":1,"symbol":"ARB_USDT","updateTime":1700000000000,"version":1},"ts":1700000000000}"#)

        guard case .positionUpdate(let position) = event else { Issue.record("Expected a position update, got \(event)"); return }
        #expect(position.positionID == 1234567890)
        #expect(position.positionType == .long)
        #expect(position.state == .holding)
        #expect(position.holdVolume == 23)
        #expect(position.liquidatePrice == 0.10127)
    }

    @Test func decodesAssetUpdate() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.asset","data":{"availableBalance":7.5,"bonus":0,"currency":"USDT","frozenBalance":0,"positionMargin":2.3},"ts":1700000000000}"#)

        guard case .assetUpdate(let asset) = event else { Issue.record("Expected an asset update, got \(event)"); return }
        #expect(asset == AssetUpdate(currency: "USDT", availableBalance: 7.5, frozenBalance: 0, positionMargin: 2.3, bonus: 0))
    }

    @Test func decodesStopPlanOrder() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.stop.planorder","data":{"createTime":1700000000000,"ensureStopLoss":0,"id":569857826,"isFinished":0,"lossTrend":1,"orderId":"0","positionId":"1234567890","positionType":1,"profitLossVolType":"SAME","profitTrend":1,"realityVol":0,"state":1,"stopLossPrice":0.18,"stopLossReverse":2,"stopLossVol":23,"symbol":"ARB_USDT","takeProfitPrice":0.22,"takeProfitReverse":2,"takeProfitVol":23,"triggerSide":0,"updateTime":1700000000000,"version":0,"vol":23,"volType":2},"ts":1700000000000}"#)

        guard case .stopPlanOrder(let order) = event else { Issue.record("Expected a TP/SL order, got \(event)"); return }
        #expect(order.id == 569857826)
        #expect(order.positionID == 1234567890)
        #expect(order.takeProfitPrice == 0.22)
        #expect(order.stopLossPrice == 0.18)
        #expect(order.profitTrend == .lastPrice)
        #expect(order.state == .untriggered)
        #expect(order.isFinished == false)
    }

    @Test func decodesPlanOrder() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.plan.order","data":{"createTime":1700000000000,"ensureStopLoss":0,"executeCycle":87600,"extraTakerFeeRate":0,"id":"860670920697239040","leverage":2,"lossTrend":1,"openType":1,"orderType":5,"positionMode":1,"profitTrend":1,"reduceOnly":false,"side":1,"state":1,"symbol":"ARB_USDT","trend":1,"triggerPrice":0.15,"triggerType":2,"updateTime":1700000000000,"vol":66},"ts":1700000000000}"#)

        guard case .planOrder(let order) = event else { Issue.record("Expected a trigger order, got \(event)"); return }
        #expect(order.id == 860670920697239040)
        #expect(order.triggerPrice == 0.15)
        #expect(order.triggerDirection == .lessThanOrEqual)
        #expect(order.triggerPriceType == .lastPrice)
        #expect(order.state == .untriggered)
        #expect(order.price == nil)
        #expect(order.volume == 66)
    }

    @Test func decodesLiquidationRisk() throws {
        let event = MexcFuturesWebSocket.Event(text: #"{"channel":"push.personal.liquidate.risk","data":{"adlLevel":0,"liquidatePrice":0.10127,"marginRatio":0.007998,"positionId":1234567890,"symbol":"ARB_USDT"},"ts":1700000000000}"#)

        guard case .liquidateRisk(let risk) = event else { Issue.record("Expected a liquidation risk, got \(event)"); return }
        #expect(risk == LiquidationRisk(symbol: "ARB_USDT", positionID: 1234567890, liquidatePrice: 0.10127, marginRatio: 0.007998, adlLevel: 0))
    }

    @Test(arguments: [("push.personal.stop.order", "stopOrder"), ("push.personal.adl.level", "adlLevel"), ("push.personal.risk.limit", "riskLimit")])
    func unmodeledChannelCarriesJSON(channel: String, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(channel: channel, data: #"{"value":42}"#)

        #expect(event.caseName == expectedCase)
        #expect((Mirror(reflecting: event).children.first?.value as? JSON)?["value"].int == 42)
    }

    @Test func decodesPong() {
        let event = MexcFuturesWebSocket.Event(channel: "pong", data: "1790869655448")

        guard case .pong(let serverTime) = event else { Issue.record("Expected a pong, got \(event)"); return }
        #expect(serverTime == Date(timeIntervalSince1970: 1_790_869_655.448))
    }

    @Test(arguments: [#""success""#, #"{"code":0}"#])
    func loginAcknowledgementDeliversMessage(data: String) {
        let event = MexcFuturesWebSocket.Event(channel: "rs.login", data: data)

        guard case .login(let message) = event else { Issue.record("Expected a login, got \(event)"); return }
        #expect(message["channel"].string == "rs.login")
    }

    @Test func loginRejectionDeliversData() {
        let event = MexcFuturesWebSocket.Event(channel: "rs.login", data: #"{"code":401,"msg":"denied"}"#)

        guard case .loginFailed(let data) = event else { Issue.record("Expected a failed login, got \(event)"); return }
        #expect(data["msg"].string == "denied")
    }

    @Test(arguments: [
        (#""success""#, "filterSet"),
        (#"{"code":0}"#, "filterSet"),
        (#""failed""#, "filterFailed"),
    ])
    func filterResponseReportsOutcome(data: String, expectedCase: String) {
        #expect(MexcFuturesWebSocket.Event(channel: "rs.personal.filter", data: data).caseName == expectedCase)
    }

    @Test(arguments: [
        ("rs.sub.depth.full", "subscribed"),
        ("rs.unsub.depth.full", "unsubscribed"),
    ])
    func subscriptionResponseNamesChannel(channel: String, expectedCase: String) {
        let event = MexcFuturesWebSocket.Event(channel: channel, data: #""success""#)

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
        let event = MexcFuturesWebSocket.Event(channel: "rs.error", data: #""invalid param""#)

        guard case .error(.server(let message)) = event else { Issue.record("Expected a server error, got \(event)"); return }
        #expect(message == "invalid param")
    }

    @Test func malformedTextDeliversError() {
        let event = MexcFuturesWebSocket.Event(text: "not json")

        guard case .error(.malformedMessage(let text)) = event else { Issue.record("Expected a malformed message, got \(event)"); return }
        #expect(text == "not json")
    }

    @Test func unknownChannelDeliversMessage() {
        let event = MexcFuturesWebSocket.Event(channel: "push.unknown", data: "1")

        guard case .message(let message) = event else { Issue.record("Expected a message, got \(event)"); return }
        #expect(message["channel"].string == "push.unknown")
    }
}

extension MexcFuturesWebSocket.Event {
    init(channel: String, data: String) {
        self.init(text: #"{"channel":"\#(channel)","data":\#(data),"ts":1}"#)
    }

    var caseName: String {
        Mirror(reflecting: self).children.first?.label ?? String(describing: self)
    }
}
