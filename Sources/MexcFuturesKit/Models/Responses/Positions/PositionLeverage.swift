/// The leverage of one side of a contract.
public struct PositionLeverage: Sendable, Hashable {
    /// The risk limit level.
    public var level: Int

    /// The largest position at this level, in contracts.
    public var maxVolume: Double

    /// The maintenance margin rate at this level.
    public var maintenanceMarginRate: Double

    /// The initial margin rate at this level.
    public var initialMarginRate: Double

    /// The position direction, or `nil` when MEXC sends a direction this SDK does not know.
    public var positionType: PositionType?

    /// The margin mode, or `nil` when MEXC sends a mode this SDK does not know.
    public var openType: OpenType?

    /// The current leverage.
    public var leverage: Int

    /// Whether MEXC limits the leverage of this account.
    public var isLimitedBySystem: Bool

    /// The maintenance margin rate that applies now.
    public var currentMaintenanceMarginRate: Double

    /// The highest leverage of the contract.
    public var maxLeverage: Int
}

extension PositionLeverage {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            level: field("level").intValue,
            maxVolume: field("maxVol").doubleValue,
            maintenanceMarginRate: field("mmr").doubleValue,
            initialMarginRate: field("imr").doubleValue,
            positionType: field("positionType").int.flatMap(PositionType.init(rawValue:)),
            openType: field("openType").int.flatMap(OpenType.init(rawValue:)),
            leverage: field("leverage").intValue,
            isLimitedBySystem: field("limitBySys").boolValue,
            currentMaintenanceMarginRate: field("currentMmr").doubleValue,
            maxLeverage: field("maxLeverageView").intValue
        )
    }
}
