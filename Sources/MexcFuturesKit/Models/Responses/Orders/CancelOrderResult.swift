/// The result of cancelling one order.
public struct CancelOrderResult: Sendable, Hashable {
    /// The identifier of the order.
    public var orderID: Int64

    /// The error code, `0` when the order was cancelled.
    public var errorCode: Int

    /// The reason the order was not cancelled.
    public var errorMessage: String
}

extension CancelOrderResult {
    init(node: JSONNode) {
        self.init(
            orderID: node["orderId"].int64Value,
            errorCode: node["errorCode"].intValue,
            errorMessage: node["errorMsg"].stringValue
        )
    }
}
