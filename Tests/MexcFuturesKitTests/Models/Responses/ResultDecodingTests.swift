import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Result decoding")
struct ResultDecodingTests {
    @Test func rejectionDecodesAsFailure() throws {
        let result = try decode(#"{"success":false,"code":2005,"message":"Balance insufficient"}"#) { $0.int64 }

        guard case .failure(.rejected(let code, let message)) = result else {
            Issue.record("Expected a rejection, got \(result)")
            return
        }
        #expect(code == 2005)
        #expect(message == "Balance insufficient")
    }

    @Test func missingDataDecodesAsMalformed() throws {
        let result = try decode(#"{"success":true,"code":0}"#) { $0.object(Ticker.init(node:)) }

        guard case .failure(.malformedMessage) = result else {
            Issue.record("Expected a malformed message, got \(result)")
            return
        }
    }

    @Test(arguments: [#"817027833053397504"#, #""817027833053397504""#])
    func decodesOrderIDFromNumberOrString(id: String) throws {
        let orderID = try decode(#"{"success":true,"code":0,"data":\#(id)}"#) { $0.int64 }.get()

        #expect(orderID == 817027833053397504)
    }

    @Test func decodesTicker() throws {
        let ticker = try decode(Fixtures.ticker) { $0.object(Ticker.init(node:)) }.get()

        #expect(ticker.contractID == 10)
        #expect(ticker.symbol == "BTC_USDT")
        #expect(ticker.lastPrice == 83501.5)
        #expect(ticker.bid1 == 83501.4)
        #expect(ticker.holdVolume == 520_000_000)
        #expect(ticker.timestamp == Date(timeIntervalSince1970: 1_790_860_413.855))
        #expect(ticker.riseFallRates.rate7Days == -0.0123)
        #expect(ticker.riseFallRatesOfTimezone == [-0.0071, -0.0042, 0.0013])
    }

    @Test func decodesContractDetail() throws {
        let contract = try decode(Fixtures.contract) { $0.object(ContractDetail.init(node:)) }.get()

        #expect(contract.symbol == "BTC_USDT")
        #expect(contract.displayNameEnglish == "BTC_USDT PERPETUAL")
        #expect(contract.contractSize == 0.0001)
        #expect(contract.maxLeverage == 500)
        #expect(contract.volumeScale == 0)
        #expect(contract.indexOrigin == ["BINANCE", "OKX"])
        #expect(contract.state == .enabled)
        #expect(contract.maxNumberOfOrders == [200, 50])
        #expect(contract.isAPIAllowed)
    }

    @Test func decodesOrderBookLevels() throws {
        let depth = try decode(
            #"{"success":true,"code":0,"data":{"asks":[[83502.1,1200,3]],"bids":[[83501.9,800]],"version":42267179204,"timestamp":1790860426579}}"#
        ) { $0.object(ContractDepth.init(node:)) }.get()

        #expect(depth.asks == [.init(price: 83502.1, volume: 1200, orderCount: 3)])
        #expect(depth.bids == [.init(price: 83501.9, volume: 800, orderCount: nil)])
        #expect(depth.version == 42267179204)
    }

    @Test func decodesOrder() throws {
        let order = try decode(Fixtures.order) { $0.object(Order.init(node:)) }.get()

        #expect(order.orderID == 817027833053397504)
        #expect(order.positionID == 12345)
        #expect(order.volume == 2)
        #expect(order.side == .openLong)
        #expect(order.category == .limit)
        #expect(order.orderType == .limit)
        #expect(order.openType == .isolated)
        #expect(order.state == .completed)
        #expect(order.dealAveragePrice == 50000.5)
        #expect(order.externalOrderID == "client-1")
        #expect(order.createTime == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(order.stopLossPrice == nil)
        #expect(order.positionMode == .hedge)
    }

    @Test func unknownOrderDecodesAsNil() throws {
        let order = try decode(#"{"success":true,"code":0}"#) { .some($0.object(Order.init(node:))) }.get()

        #expect(order == nil)
    }

    @Test func unknownCodeDecodesAsNil() throws {
        let order = try decode(#"{"success":true,"code":0,"data":{"orderId":1,"side":9,"state":99}}"#) { $0.object(Order.init(node:)) }.get()

        #expect(order.side == nil)
        #expect(order.state == nil)
    }

    @Test func decodesOrderDeal() throws {
        let deals = try decode(Fixtures.deals) { $0.map(OrderDeal.init(node:)) }.get()

        #expect(deals.count == 1)
        #expect(deals[0].orderID == 817027833053397504)
        #expect(deals[0].volume == 1)
        #expect(deals[0].price == 50000)
        #expect(deals[0].id == 991)
        #expect(deals[0].isTaker)
        #expect(deals[0].side == .closeLong)
        #expect(deals[0].positionMode == .hedge)
    }

    @Test func decodesPosition() throws {
        let positions = try decode(Fixtures.positions) { $0.map(Position.init(node:)) }.get()

        #expect(positions.count == 1)
        #expect(positions[0].positionType == .long)
        #expect(positions[0].state == .holding)
        #expect(positions[0].holdVolume == 3)
        #expect(positions[0].originalInitialMargin == 15.2)
        #expect(positions[0].adlLevel == 2)
        #expect(positions[0].autoAddInitialMargin == false)
    }

    @Test func decodesAccountAsset() throws {
        let asset = try decode(Fixtures.asset) { $0.object(AccountAsset.init(node:)) }.get()

        #expect(asset.currency == "USDT")
        #expect(asset.availableBalance == 120.5)
        #expect(asset.equity == 135.25)
    }

    @Test(arguments: [Fixtures.riskLimitsByContract, Fixtures.riskLimitsList])
    func decodesRiskLimitsInEitherShape(text: String) throws {
        let limits = try decode(text) { data in
            data.map(RiskLimit.init(node:)) ?? data.members()?.flatMap { $0.value.map(RiskLimit.init(node:)) ?? [] }
        }.get()

        #expect(limits.count == 1)
        #expect(limits[0].symbol == "BTC_USDT")
        #expect(limits[0].level == 1)
        #expect(limits[0].maxLeverage == 125)
        #expect(limits[0].maxVolume == 500_000)
        #expect(limits[0].maintenanceMarginRate == 0.004)
    }

    @Test func decodesCancelResults() throws {
        let results = try decode(
            #"{"success":true,"code":0,"data":[{"orderId":817027833053397504,"errorCode":0,"errorMsg":"success"},{"orderId":"2","errorCode":2041,"errorMsg":"order not exist"}]}"#
        ) { $0.map(CancelOrderResult.init(node:)) }.get()

        #expect(results == [
            .init(orderID: 817027833053397504, errorCode: 0, errorMessage: "success"),
            .init(orderID: 2, errorCode: 2041, errorMessage: "order not exist"),
        ])
    }

    @Test func decodesFeeRatesAndExternalReference() throws {
        let rates = try decode(#"{"success":true,"code":0,"data":[{"symbol":"BTC_USDT","takerFeeRate":0.0002,"makerFeeRate":0}]}"#) { $0.map(FeeRate.init(node:)) }.get()
        let reference = try decode(#"{"success":true,"code":0,"data":{"symbol":"BTC_USDT","externalOid":"client-1"}}"#) { $0.object(ExternalOrderReference.init(node:)) }.get()

        #expect(rates == [FeeRate(symbol: "BTC_USDT", takerFeeRate: 0.0002, makerFeeRate: 0)])
        #expect(reference == ExternalOrderReference(symbol: "BTC_USDT", externalOrderID: "client-1"))
    }

    private func decode<Value>(
        _ text: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        data: (JSONNode) -> Value?
    ) throws -> Result<Value, MexcFuturesError> {
        let document = try #require(JSONDocument.parse(Data(text.utf8)), sourceLocation: sourceLocation)
        return document.decode { Result(response: $0, data: data) }
    }
}

private enum Fixtures {
    static let ticker = #"""
    {"success":true,"code":0,"data":{"contractId":10,"symbol":"BTC_USDT","lastPrice":83501.5,"bid1":83501.4,"ask1":83501.6,
    "volume24":324693549,"amount24":2712345678.9,"holdVol":520000000,"lower24Price":82000.1,"high24Price":84500,"riseFallRate":-0.0071,
    "riseFallValue":-597.5,"indexPrice":83536.2,"fairPrice":83502.6,"fundingRate":0.0001,"maxBidPrice":91851.6,"minAskPrice":75151.3,
    "timestamp":1790860413855,"riseFallRates":{"zone":"UTC+8","r":-0.0071,"v":-597.5,"r7":-0.0123,"r30":0.04,"r90":0.1,"r180":0.2,"r365":0.5},
    "riseFallRatesOfTimezone":[-0.0071,-0.0042,0.0013]}}
    """#

    static let contract = #"""
    {"success":true,"code":0,"data":{"symbol":"BTC_USDT","displayName":"BTC_USDT永续","displayNameEn":"BTC_USDT PERPETUAL","positionOpenType":3,
    "baseCoin":"BTC","quoteCoin":"USDT","settleCoin":"USDT","contractSize":0.0001,"minLeverage":1,"maxLeverage":500,"priceScale":1,"volScale":0,
    "amountScale":4,"priceUnit":0.1,"volUnit":1,"minVol":1,"maxVol":1500000,"bidLimitPriceRate":0.1,"askLimitPriceRate":0.1,"takerFeeRate":0.0002,
    "makerFeeRate":0,"maintenanceMarginRate":0.004,"initialMarginRate":0.008,"riskBaseVol":500000,"riskIncrVol":500000,"riskIncrMmr":0.004,
    "riskIncrImr":0.004,"riskLevelLimit":6,"priceCoefficientVariation":0.05,"indexOrigin":["BINANCE","OKX"],"state":0,"isNew":false,"isHot":true,
    "isHidden":false,"conceptPlate":["mc-trade-zone-pow"],"riskLimitType":"BY_VOLUME","maxNumOrders":[200,50],"marketOrderMaxLevel":20,
    "marketOrderPriceLimitRate1":0.2,"marketOrderPriceLimitRate2":0.005,"triggerProtect":0.1,"appraisal":0,"showAppraisalCountdown":0,
    "automaticDelivery":0,"apiAllowed":true}}
    """#

    static let order = #"""
    {"success":true,"code":0,"data":{"orderId":"817027833053397504","symbol":"BTC_USDT","positionId":12345,"price":50000.5,"priceStr":"50000.5","vol":2,"leverage":10,
    "side":1,"category":1,"orderType":1,"dealAvgPrice":50000.5,"dealVol":2,"orderMargin":10.01,"takerFee":0,"makerFee":0.02,"profit":0,
    "feeCurrency":"USDT","openType":1,"state":3,"externalOid":"client-1","errorCode":0,"usedMargin":10.01,"createTime":1700000000000,
    "updateTime":1700000001000,"positionMode":1,"version":2,"takerFeeRate":0.0004,"makerFeeRate":0.0001}}
    """#

    static let deals = #"""
    {"success":true,"code":0,"data":[{"id":"991","symbol":"BTC_USDT","side":4,"vol":1,"price":50000,"fee":0.01,"feeCurrency":"USDT","profit":2.5,
    "category":1,"orderId":"817027833053397504","timestamp":1700000002000,"positionMode":1,"taker":true}]}
    """#

    static let positions = #"""
    {"success":true,"code":0,"data":[{"positionId":12345,"symbol":"BTC_USDT","positionType":1,"openType":1,"state":1,"holdVol":3,"frozenVol":0,
    "closeVol":0,"holdAvgPrice":50000,"openAvgPrice":50000,"closeAvgPrice":0,"liquidatePrice":45500,"oim":15.2,"im":15.2,"holdFee":-0.01,
    "realised":-0.03,"adlLevel":2,"leverage":10,"createTime":1700000000000,"updateTime":1700000001000,"autoAddIm":false}]}
    """#

    static let asset = #"""
    {"success":true,"code":0,"data":{"currency":"USDT","positionMargin":15.2,"availableBalance":120.5,"cashBalance":135.7,"frozenBalance":0,
    "equity":135.25,"unrealized":-0.45,"bonus":0}}
    """#

    static let riskLimitsByContract = #"""
    {"success":true,"code":0,"data":{"BTC_USDT":[{"level":1,"maxVol":500000,"maxLeverage":125,"mmr":0.004,"imr":0.008,"symbol":"BTC_USDT","positionType":1}]}}
    """#

    static let riskLimitsList = #"""
    {"success":true,"code":0,"data":[{"symbol":"BTC_USDT","level":1,"maxLeverage":125,"riskLimit":500000,"maintMarginRate":0.004}]}
    """#
}
