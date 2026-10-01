/// A response from the MEXC futures REST API.
///
/// MEXC reports most rejections inside a successful HTTP response, so check ``success``
/// before reading ``data``:
///
/// ```swift
/// let response = try await client.ticker(symbol: "BTC_USDT")
/// if response.success, let ticker = response.data {
///     print(ticker.lastPrice)
/// }
/// ```
public struct Response<Payload: Sendable>: Sendable {
    /// Whether MEXC accepted the request.
    public var success: Bool

    /// The MEXC result code, `0` when the request succeeded.
    public var code: Int

    /// The reason MEXC gave when it rejected the request.
    public var message: String?

    /// The result of the request, or `nil` when the response carries none.
    public var data: Payload?
}

extension Response: Equatable where Payload: Equatable {}

extension Response: Hashable where Payload: Hashable {}

extension Response {
    init(node: JSONNode, payload: (JSONNode) -> Payload?) {
        let data = node["data"]
        self.init(
            success: node["success"].boolValue,
            code: node["code"].intValue,
            message: node["message"].string,
            data: data.exists ? payload(data) : nil
        )
    }
}
