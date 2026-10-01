/// One risk limit level of a contract.
public struct RiskLimit: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The risk limit level.
    public var level: Int

    /// The highest leverage at this level.
    public var maxLeverage: Int

    /// The largest position at this level.
    public var maxVolume: Double

    /// The maintenance margin rate at this level.
    public var maintenanceMarginRate: Double

    /// The initial margin rate at this level, when MEXC reports it.
    public var initialMarginRate: Double?

    /// The position direction the level applies to, when MEXC reports it.
    public var positionType: PositionType?
}

extension RiskLimit {
    init(node: JSONNode) {
        self.init(
            symbol: node["symbol"].stringValue,
            level: node["level"].intValue,
            maxLeverage: node["maxLeverage"].intValue,
            maxVolume: node["maxVol"].double ?? node["riskLimit"].doubleValue,
            maintenanceMarginRate: node["mmr"].double ?? node["maintMarginRate"].doubleValue,
            initialMarginRate: node["imr"].double,
            positionType: node["positionType"].int.flatMap(PositionType.init(rawValue:))
        )
    }
}
