/// A reference price of a contract, such as its index price or fair price.
public struct ContractPrice: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The price.
    public var price: Double
}

extension ContractPrice {
    init(node: JSONNode) {
        self.init(symbol: node["symbol"].stringValue, price: node["price"].doubleValue)
    }
}
