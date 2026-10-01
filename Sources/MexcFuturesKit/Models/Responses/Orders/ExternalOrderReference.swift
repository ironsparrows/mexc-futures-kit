/// An order identified by its contract and client-assigned identifier.
public struct ExternalOrderReference: Sendable, Hashable {
    /// The contract symbol, such as `BTC_USDT`.
    public var symbol: String

    /// The client-assigned order identifier.
    public var externalOrderID: String
}

extension ExternalOrderReference: Encodable {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case externalOrderID = "externalOid"
    }
}

extension ExternalOrderReference {
    init(node: JSONNode) {
        self.init(symbol: node["symbol"].stringValue, externalOrderID: node["externalOid"].stringValue)
    }
}
