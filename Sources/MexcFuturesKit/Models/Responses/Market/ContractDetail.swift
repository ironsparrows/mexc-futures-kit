/// The specification of a contract.
public struct ContractDetail: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The display name in the account's language.
    public var displayName: String

    /// The English display name.
    public var displayNameEnglish: String

    /// The margin modes the contract supports: 1 isolated, 2 cross, 3 both.
    public var positionOpenType: Int

    /// The base currency.
    public var baseCoin: String

    /// The quote currency.
    public var quoteCoin: String

    /// The settlement currency.
    public var settleCoin: String

    /// The value of one contract, in the base currency.
    public var contractSize: Double

    /// The lowest leverage.
    public var minLeverage: Int

    /// The highest leverage.
    public var maxLeverage: Int

    /// The number of decimal places of the price.
    public var priceScale: Int

    /// The number of decimal places of the volume.
    public var volumeScale: Int

    /// The number of decimal places of the amount.
    public var amountScale: Int

    /// The smallest price step.
    public var priceUnit: Double

    /// The smallest volume step.
    public var volumeUnit: Double

    /// The smallest order volume.
    public var minVolume: Double

    /// The largest order volume.
    public var maxVolume: Double

    /// The bid price limit rate.
    public var bidLimitPriceRate: Double

    /// The ask price limit rate.
    public var askLimitPriceRate: Double

    /// The taker fee rate.
    public var takerFeeRate: Double

    /// The maker fee rate.
    public var makerFeeRate: Double

    /// The maintenance margin rate.
    public var maintenanceMarginRate: Double

    /// The initial margin rate.
    public var initialMarginRate: Double

    /// The base volume of the risk limit.
    public var riskBaseVolume: Double

    /// The volume increment of the risk limit.
    public var riskIncrementVolume: Double

    /// The maintenance margin rate increment of the risk limit.
    public var riskIncrementMMR: Double

    /// The initial margin rate increment of the risk limit.
    public var riskIncrementIMR: Double

    /// The number of risk limit levels.
    public var riskLevelLimit: Int

    /// The price coefficient variation.
    public var priceCoefficientVariation: Double

    /// The exchanges the index price comes from.
    public var indexOrigin: [String]

    /// The trading state, or `nil` when MEXC sends a state this SDK does not know.
    public var state: ContractState?

    /// Whether the contract is newly listed.
    public var isNew: Bool

    /// Whether the contract is popular.
    public var isHot: Bool

    /// Whether the contract is hidden.
    public var isHidden: Bool

    /// The sectors the contract belongs to.
    public var conceptPlate: [String]

    /// How the risk limit is measured, such as `BY_VOLUME` or `BY_VALUE`.
    public var riskLimitType: String

    /// The maximum numbers of open orders.
    public var maxNumberOfOrders: [Int]

    /// The deepest price level a market order may fill.
    public var marketOrderMaxLevel: Int

    /// The first price limit rate of market orders.
    public var marketOrderPriceLimitRate1: Double

    /// The second price limit rate of market orders.
    public var marketOrderPriceLimitRate2: Double

    /// The trigger protection threshold.
    public var triggerProtect: Double

    /// The appraisal flag.
    public var appraisal: Int

    /// The appraisal countdown flag.
    public var showAppraisalCountdown: Int

    /// The automatic delivery flag.
    public var automaticDelivery: Int

    /// Whether the contract can be traded through the API.
    public var isAPIAllowed: Bool
}

extension ContractDetail {
    init(node: JSONNode) {
        var field = JSONObjectReader(node)
        self.init(
            symbol: field("symbol").stringValue,
            displayName: field("displayName").stringValue,
            displayNameEnglish: field("displayNameEn").stringValue,
            positionOpenType: field("positionOpenType").intValue,
            baseCoin: field("baseCoin").stringValue,
            quoteCoin: field("quoteCoin").stringValue,
            settleCoin: field("settleCoin").stringValue,
            contractSize: field("contractSize").doubleValue,
            minLeverage: field("minLeverage").intValue,
            maxLeverage: field("maxLeverage").intValue,
            priceScale: field("priceScale").intValue,
            volumeScale: field("volScale").intValue,
            amountScale: field("amountScale").intValue,
            priceUnit: field("priceUnit").doubleValue,
            volumeUnit: field("volUnit").doubleValue,
            minVolume: field("minVol").doubleValue,
            maxVolume: field("maxVol").doubleValue,
            bidLimitPriceRate: field("bidLimitPriceRate").doubleValue,
            askLimitPriceRate: field("askLimitPriceRate").doubleValue,
            takerFeeRate: field("takerFeeRate").doubleValue,
            makerFeeRate: field("makerFeeRate").doubleValue,
            maintenanceMarginRate: field("maintenanceMarginRate").doubleValue,
            initialMarginRate: field("initialMarginRate").doubleValue,
            riskBaseVolume: field("riskBaseVol").doubleValue,
            riskIncrementVolume: field("riskIncrVol").doubleValue,
            riskIncrementMMR: field("riskIncrMmr").doubleValue,
            riskIncrementIMR: field("riskIncrImr").doubleValue,
            riskLevelLimit: field("riskLevelLimit").intValue,
            priceCoefficientVariation: field("priceCoefficientVariation").doubleValue,
            indexOrigin: field("indexOrigin").map(\.stringValue) ?? [],
            state: field("state").int.flatMap(ContractState.init(rawValue:)),
            isNew: field("isNew").boolValue,
            isHot: field("isHot").boolValue,
            isHidden: field("isHidden").boolValue,
            conceptPlate: field("conceptPlate").map(\.stringValue) ?? [],
            riskLimitType: field("riskLimitType").stringValue,
            maxNumberOfOrders: field("maxNumOrders").map(\.intValue) ?? [],
            marketOrderMaxLevel: field("marketOrderMaxLevel").intValue,
            marketOrderPriceLimitRate1: field("marketOrderPriceLimitRate1").doubleValue,
            marketOrderPriceLimitRate2: field("marketOrderPriceLimitRate2").doubleValue,
            triggerProtect: field("triggerProtect").doubleValue,
            appraisal: field("appraisal").intValue,
            showAppraisalCountdown: field("showAppraisalCountdown").intValue,
            automaticDelivery: field("automaticDelivery").intValue,
            isAPIAllowed: field("apiAllowed").boolValue
        )
    }
}
