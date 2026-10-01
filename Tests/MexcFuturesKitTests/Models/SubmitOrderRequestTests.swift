import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("SubmitOrderRequest")
struct SubmitOrderRequestTests {
    static let marketOrder = SubmitOrderRequest(
        symbol: "BTC_USDT",
        price: 50000,
        volume: 0.001,
        side: .openLong,
        type: .market,
        openType: .isolated,
        leverage: 10
    )

    @Test func encodesWireKeysAndOmitsUnsetFields() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let json = String(decoding: try encoder.encode(Self.marketOrder), as: UTF8.self)

        #expect(json == #"{"leverage":10,"openType":1,"price":50000,"side":1,"symbol":"BTC_USDT","type":5,"vol":0.001}"#)
    }

    @Test func encodesOptionalFields() throws {
        var request = Self.marketOrder
        request.positionID = 817027833053397504
        request.externalOrderID = "client-1"
        request.stopLossPrice = 45000
        request.takeProfitPrice = 60000
        request.positionMode = .oneWay
        request.reduceOnly = true
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let json = String(decoding: try encoder.encode(request), as: UTF8.self)

        #expect(json == #"{"externalOid":"client-1","leverage":10,"openType":1,"positionId":817027833053397504,"positionMode":2,"price":50000,"reduceOnly":true,"side":1,"stopLossPrice":45000,"symbol":"BTC_USDT","takeProfitPrice":60000,"type":5,"vol":0.001}"#)
    }

    @Test func validRequestPassesValidation() {
        #expect(throws: Never.self) {
            try Self.marketOrder.validate()
        }
    }

    @Test(arguments: [
        (SubmitOrderRequest.with(\.symbol, ""), "symbol"),
        (.with(\.price, -1), "price"),
        (.with(\.price, .nan), "price"),
        (.with(\.volume, 0), "volume"),
        (.with(\.volume, .infinity), "volume"),
        (.with(\.leverage, 0), "leverage"),
        (.with(\.stopLossPrice, -1), "stopLossPrice"),
        (.with(\.takeProfitPrice, .nan), "takeProfitPrice"),
    ])
    func invalidRequestNamesField(request: SubmitOrderRequest, field: String) {
        let error = #expect(throws: MexcFuturesError.self) {
            try request.validate()
        }

        guard case .validation(_, let invalidField) = error else {
            Issue.record("Expected a validation error, got \(String(describing: error))")
            return
        }
        #expect(invalidField == field)
    }
}

private extension SubmitOrderRequest {
    static func with<Value>(_ keyPath: WritableKeyPath<Self, Value>, _ value: Value) -> Self {
        var request = SubmitOrderRequestTests.marketOrder
        request[keyPath: keyPath] = value
        return request
    }
}
