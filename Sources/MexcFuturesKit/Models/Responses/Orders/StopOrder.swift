public import Foundation

/// A take-profit and stop-loss order attached to a position.
public struct StopOrder: Sendable, Hashable {
    /// The TP/SL order identifier.
    public var id: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The identifier of the position the order protects.
    public var positionID: Int64

    /// The direction of the position, or `nil` when MEXC sends a direction this SDK does not know.
    public var positionType: PositionType?

    /// The take-profit trigger price, when one is set.
    public var takeProfitPrice: Double?

    /// The stop-loss trigger price, when one is set.
    public var stopLossPrice: Double?

    /// The volume closed by the take-profit, in contracts.
    public var takeProfitVolume: Double

    /// The volume closed by the stop-loss, in contracts.
    public var stopLossVolume: Double

    /// The volume of the order, in contracts.
    public var volume: Double

    /// The price the take-profit watches, or `nil` when MEXC sends a price type this SDK does not know.
    public var profitTrend: TriggerPriceType?

    /// The price the stop-loss watches, or `nil` when MEXC sends a price type this SDK does not know.
    public var lossTrend: TriggerPriceType?

    /// The lifecycle state, or `nil` when MEXC sends a state this SDK does not know.
    public var state: TriggerOrderState?

    /// Whether the order has finished.
    public var isFinished: Bool

    /// The time the order was created.
    public var createTime: Date

    /// The time the order last changed.
    public var updateTime: Date
}

extension StopOrder {
    init(node: JSONNode) {
        self.init(
            id: node["id"].int64Value,
            symbol: node["symbol"].stringValue,
            positionID: node["positionId"].int64Value,
            positionType: node["positionType"].int.flatMap(PositionType.init(rawValue:)),
            takeProfitPrice: node["takeProfitPrice"].double.flatMap { $0 > 0 ? $0 : nil },
            stopLossPrice: node["stopLossPrice"].double.flatMap { $0 > 0 ? $0 : nil },
            takeProfitVolume: node["takeProfitVol"].doubleValue,
            stopLossVolume: node["stopLossVol"].doubleValue,
            volume: node["vol"].doubleValue,
            profitTrend: node["profitTrend"].int.flatMap(TriggerPriceType.init(rawValue:)),
            lossTrend: node["lossTrend"].int.flatMap(TriggerPriceType.init(rawValue:)),
            state: node["state"].int.flatMap(TriggerOrderState.init(rawValue:)),
            isFinished: node["isFinished"].boolValue,
            createTime: node["createTime"].dateValue,
            updateTime: node["updateTime"].dateValue
        )
    }
}
