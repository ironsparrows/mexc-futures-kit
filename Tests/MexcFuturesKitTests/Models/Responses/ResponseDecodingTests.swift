import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Response decoding")
struct ResponseDecodingTests {
    @Test func decodesEnvelope() throws {
        let response = try decode(#"{"success":false,"code":2005,"message":"Balance insufficient"}"#) { $0.int64 }

        #expect(response.success == false)
        #expect(response.code == 2005)
        #expect(response.message == "Balance insufficient")
        #expect(response.data == nil)
    }

    @Test(arguments: [#"817027833053397504"#, #""817027833053397504""#])
    func decodesOrderIDFromNumberOrString(id: String) throws {
        let response = try decode(#"{"success":true,"code":0,"data":\#(id)}"#) { $0.int64 }

        #expect(response.data == 817027833053397504)
    }

    @Test func decodesTicker() throws {
        let ticker = try #require(try decode(Fixtures.ticker, payload: Ticker.init(node:)).data)

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
        let contract = try #require(try decode(Fixtures.contract, payload: ContractDetail.init(node:)).data)

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
        let depth = try #require(try decode(
            #"{"success":true,"code":0,"data":{"asks":[[83502.1,1200,3]],"bids":[[83501.9,800]],"version":42267179204,"timestamp":1790860426579}}"#,
            payload: ContractDepth.init(node:)
        ).data)

        #expect(depth.asks == [.init(price: 83502.1, volume: 1200, orderCount: 3)])
        #expect(depth.bids == [.init(price: 83501.9, volume: 800, orderCount: nil)])
        #expect(depth.version == 42267179204)
    }

    @Test func decodesOrder() throws {
        let order = try #require(try decode(Fixtures.order, payload: Order.init(node:)).data)

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
    }

    @Test func unknownCodeDecodesAsNil() throws {
        let order = try #require(try decode(#"{"success":true,"code":0,"data":{"orderId":1,"side":9,"state":99}}"#, payload: Order.init(node:)).data)

        #expect(order.side == nil)
        #expect(order.state == nil)
    }

    @Test func decodesOrderDeal() throws {
        let deals = try #require(try decode(Fixtures.deals) { $0.map(OrderDeal.init(node:)) }.data)

        #expect(deals.count == 1)
        #expect(deals[0].orderID == 817027833053397504)
        #expect(deals[0].volume == 1)
        #expect(deals[0].price == 50000)
        #expect(deals[0].isTaker)
        #expect(deals[0].side == .closeLong)
    }

    @Test func decodesPosition() throws {
        let positions = try #require(try decode(Fixtures.positions) { $0.map(Position.init(node:)) }.data)

        #expect(positions.count == 1)
        #expect(positions[0].positionType == .long)
        #expect(positions[0].state == .holding)
        #expect(positions[0].holdVolume == 3)
        #expect(positions[0].originalInitialMargin == 15.2)
        #expect(positions[0].adlLevel == 2)
        #expect(positions[0].autoAddInitialMargin == false)
    }

    @Test func decodesAccountAsset() throws {
        let asset = try #require(try decode(Fixtures.asset, payload: AccountAsset.init(node:)).data)

        #expect(asset.currency == "USDT")
        #expect(asset.availableBalance == 120.5)
        #expect(asset.equity == 135.25)
    }

    @Test(arguments: [Fixtures.riskLimitsByContract, Fixtures.riskLimitsList])
    func decodesRiskLimitsInEitherShape(text: String) throws {
        let limits = try #require(try decode(text) { data in
            data.map(RiskLimit.init(node:)) ?? data.members()?.flatMap { $0.value.map(RiskLimit.init(node:)) ?? [] }
        }.data)

        #expect(limits.count == 1)
        #expect(limits[0].symbol == "BTC_USDT")
        #expect(limits[0].level == 1)
        #expect(limits[0].maxLeverage == 125)
        #expect(limits[0].maxVolume == 500_000)
        #expect(limits[0].maintenanceMarginRate == 0.004)
    }

    @Test func decodesCancelResults() throws {
        let results = try #require(try decode(
            #"{"success":true,"code":0,"data":[{"orderId":817027833053397504,"errorCode":0,"errorMsg":"success"},{"orderId":"2","errorCode":2041,"errorMsg":"order not exist"}]}"#
        ) { $0.map(CancelOrderResult.init(node:)) }.data)

        #expect(results == [
            .init(orderID: 817027833053397504, errorCode: 0, errorMessage: "success"),
            .init(orderID: 2, errorCode: 2041, errorMessage: "order not exist"),
        ])
    }

    @Test func decodesFeeRatesAndExternalReference() throws {
        let rates = try #require(try decode(#"{"success":true,"code":0,"data":[{"symbol":"BTC_USDT","takerFeeRate":0.0002,"makerFeeRate":0}]}"#) { $0.map(FeeRate.init(node:)) }.data)
        let reference = try #require(try decode(#"{"success":true,"code":0,"data":{"symbol":"BTC_USDT","externalOid":"client-1"}}"#, payload: ExternalOrderReference.init(node:)).data)

        #expect(rates == [FeeRate(symbol: "BTC_USDT", takerFeeRate: 0.0002, makerFeeRate: 0)])
        #expect(reference == ExternalOrderReference(symbol: "BTC_USDT", externalOrderID: "client-1"))
    }

    private func decode<Payload>(
        _ text: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        payload: (JSONNode) -> Payload?
    ) throws -> Response<Payload> {
        let document = try #require(JSONDocument.parse(Data(text.utf8)), sourceLocation: sourceLocation)
        return document.decode { Response(node: $0, payload: payload) }
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
    {"success":true,"code":0,"data":{"orderId":817027833053397504,"symbol":"BTC_USDT","positionId":12345,"price":50000.5,"vol":2,"leverage":10,
    "side":1,"category":1,"orderType":1,"dealAvgPrice":50000.5,"dealVol":2,"orderMargin":10.01,"takerFee":0,"makerFee":0.02,"profit":0,
    "feeCurrency":"USDT","openType":1,"state":3,"externalOid":"client-1","errorCode":0,"usedMargin":10.01,"createTime":1700000000000,
    "updateTime":1700000001000}}
    """#

    static let deals = #"""
    {"success":true,"code":0,"data":[{"id":991,"symbol":"BTC_USDT","side":4,"vol":1,"price":50000,"fee":0.01,"feeCurrency":"USDT","profit":2.5,
    "isTaker":true,"category":1,"orderId":817027833053397504,"timestamp":1700000002000}]}
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
