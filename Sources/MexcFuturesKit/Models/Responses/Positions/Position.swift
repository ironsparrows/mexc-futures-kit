public import Foundation

/// A futures position.
public struct Position: Sendable, Hashable {
    /// The position identifier.
    public var positionID: Int64

    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The position direction, or `nil` when MEXC sends a direction this SDK does not know.
    public var positionType: PositionType?

    /// The margin mode, or `nil` when MEXC sends a mode this SDK does not know.
    public var openType: OpenType?

    /// The lifecycle state, or `nil` when MEXC sends a state this SDK does not know.
    public var state: PositionState?

    /// The held volume, in contracts.
    public var holdVolume: Double

    /// The volume reserved by closing orders, in contracts.
    public var frozenVolume: Double

    /// The closed volume, in contracts.
    public var closeVolume: Double

    /// The average price of the held volume.
    public var holdAveragePrice: Double

    /// The average opening price.
    public var openAveragePrice: Double

    /// The average closing price.
    public var closeAveragePrice: Double

    /// The liquidation price.
    public var liquidatePrice: Double

    /// The original initial margin.
    public var originalInitialMargin: Double

    /// The auto-deleveraging level from 1 to 5, when MEXC reports it.
    public var adlLevel: Int?

    /// The initial margin.
    public var initialMargin: Double

    /// The funding fees, positive when received and negative when paid.
    public var holdFee: Double

    /// The realized profit and loss.
    public var realised: Double

    /// The leverage.
    public var leverage: Int

    /// The time the position was opened.
    public var createTime: Date

    /// The time the position last changed.
    public var updateTime: Date

    /// Whether margin is added automatically to avoid liquidation.
    public var autoAddInitialMargin: Bool?
}

extension Position {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            positionID: field("positionId").int64Value,
            symbol: field("symbol").stringValue,
            positionType: field("positionType").int.flatMap(PositionType.init(rawValue:)),
            openType: field("openType").int.flatMap(OpenType.init(rawValue:)),
            state: field("state").int.flatMap(PositionState.init(rawValue:)),
            holdVolume: field("holdVol").doubleValue,
            frozenVolume: field("frozenVol").doubleValue,
            closeVolume: field("closeVol").doubleValue,
            holdAveragePrice: field("holdAvgPrice").doubleValue,
            openAveragePrice: field("openAvgPrice").doubleValue,
            closeAveragePrice: field("closeAvgPrice").doubleValue,
            liquidatePrice: field("liquidatePrice").doubleValue,
            originalInitialMargin: field("oim").doubleValue,
            adlLevel: field("adlLevel").int,
            initialMargin: field("im").doubleValue,
            holdFee: field("holdFee").doubleValue,
            realised: field("realised").doubleValue,
            leverage: field("leverage").intValue,
            createTime: field("createTime").dateValue,
            updateTime: field("updateTime").dateValue,
            autoAddInitialMargin: field("autoAddIm").bool
        )
    }
}
