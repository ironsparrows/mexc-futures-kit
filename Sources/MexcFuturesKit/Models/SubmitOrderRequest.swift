/// The parameters of a new futures order.
public struct SubmitOrderRequest: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The order price.
    public var price: Double

    /// The order volume, in contracts.
    public var volume: Double

    /// The order direction.
    public var side: OrderSide

    /// The order execution type.
    public var type: OrderType

    /// The margin mode.
    public var openType: OpenType

    /// The leverage, required for isolated margin.
    public var leverage: Int?

    /// The position to close, recommended when closing a position.
    public var positionID: Int64?

    /// A client-assigned order identifier.
    public var externalOrderID: String?

    /// The stop-loss trigger price.
    public var stopLossPrice: Double?

    /// The take-profit trigger price.
    public var takeProfitPrice: Double?

    /// The position mode, defaulting to the account's current mode.
    public var positionMode: PositionMode?

    /// Whether the order may only reduce a one-way position.
    public var reduceOnly: Bool?

    /// Creates the parameters of a new futures order.
    public init(
        symbol: String,
        price: Double,
        volume: Double,
        side: OrderSide,
        type: OrderType,
        openType: OpenType,
        leverage: Int? = nil,
        positionID: Int64? = nil,
        externalOrderID: String? = nil,
        stopLossPrice: Double? = nil,
        takeProfitPrice: Double? = nil,
        positionMode: PositionMode? = nil,
        reduceOnly: Bool? = nil
    ) {
        self.symbol = symbol
        self.price = price
        self.volume = volume
        self.side = side
        self.type = type
        self.openType = openType
        self.leverage = leverage
        self.positionID = positionID
        self.externalOrderID = externalOrderID
        self.stopLossPrice = stopLossPrice
        self.takeProfitPrice = takeProfitPrice
        self.positionMode = positionMode
        self.reduceOnly = reduceOnly
    }
}

extension SubmitOrderRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case price
        case volume = "vol"
        case leverage
        case side
        case type
        case openType
        case positionID = "positionId"
        case externalOrderID = "externalOid"
        case stopLossPrice
        case takeProfitPrice
        case positionMode
        case reduceOnly
    }
}

extension SubmitOrderRequest {
    func validate() throws(MexcFuturesError) {
        guard !symbol.isEmpty else {
            throw .validation(message: "symbol is required", field: "symbol")
        }
        guard price.isFinite, price >= 0 else {
            throw .validation(message: "price must be a finite number >= 0", field: "price")
        }
        guard volume.isFinite, volume > 0 else {
            throw .validation(message: "volume must be a finite number > 0", field: "volume")
        }
        if let leverage, leverage <= 0 {
            throw .validation(message: "leverage must be > 0", field: "leverage")
        }
        if let stopLossPrice, !stopLossPrice.isFinite || stopLossPrice < 0 {
            throw .validation(message: "stopLossPrice must be a finite number >= 0", field: "stopLossPrice")
        }
        if let takeProfitPrice, !takeProfitPrice.isFinite || takeProfitPrice < 0 {
            throw .validation(message: "takeProfitPrice must be a finite number >= 0", field: "takeProfitPrice")
        }
    }
}
