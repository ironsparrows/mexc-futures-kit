public import Foundation
public import Logging
public import SwiftyJSON

/// A client for the MEXC futures REST API.
///
/// Private endpoints authenticate with the WEB token of a signed-in browser session.
/// Every method returns the full response body, including the `success`, `code` and `data` fields:
///
/// ```swift
/// let client = MexcFuturesClient(configuration: .init(authToken: "WEB..."))
/// let ticker = try await client.ticker(symbol: "BTC_USDT")
/// print(ticker["data"]["lastPrice"].doubleValue)
/// ```
public struct MexcFuturesClient: Sendable {
    /// The settings of the client.
    public let configuration: Configuration

    private let transport: any HTTPTransport
    private let logger: Logger

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - configuration: The settings of the client.
    ///   - session: The URL session that performs the requests.
    ///   - logger: The logger that records requests and responses.
    public init(
        configuration: Configuration,
        session: URLSession = .shared,
        logger: Logger = Logger(label: "MexcFuturesKit")
    ) {
        self.init(configuration: configuration, transport: session, logger: logger)
    }

    init(configuration: Configuration, transport: any HTTPTransport, logger: Logger) {
        self.configuration = configuration
        self.transport = transport
        self.logger = logger
    }
}

extension MexcFuturesClient {
    /// Submits a new order.
    ///
    /// The request is validated before it is signed and sent.
    ///
    /// - Parameter request: The parameters of the order.
    /// - Returns: The response body, whose `data` field holds the order identifier.
    @discardableResult
    public func submitOrder(_ request: SubmitOrderRequest) async throws(MexcFuturesError) -> JSON {
        try request.validate()
        logger.debug("Submitting order", metadata: ["symbol": "\(request.symbol)", "side": "\(request.side)", "type": "\(request.type)"])
        return try await post(.submitOrder, body: request)
    }

    /// Cancels up to 50 orders.
    ///
    /// - Parameter orderIDs: The identifiers of the orders to cancel.
    /// - Returns: The response body, whose `data` field lists the result for each order.
    @discardableResult
    public func cancelOrders(_ orderIDs: [Int64]) async throws(MexcFuturesError) -> JSON {
        guard !orderIDs.isEmpty else {
            throw .validation(message: "Order IDs array cannot be empty", field: "orderIDs")
        }
        guard orderIDs.count <= 50 else {
            throw .validation(message: "Cannot cancel more than 50 orders at once", field: "orderIDs")
        }
        return try await post(.cancelOrder, body: orderIDs.map(String.init))
    }

    /// Cancels the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response body.
    @discardableResult
    public func cancelOrder(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> JSON {
        try await post(.cancelOrderByExternalID, body: ExternalOrderReference(symbol: symbol, externalOid: externalOrderID))
    }

    /// Cancels every open order of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` to cancel the orders of every contract.
    /// - Returns: The response body.
    @discardableResult
    public func cancelAllOrders(symbol: String? = nil) async throws(MexcFuturesError) -> JSON {
        try await post(.cancelAllOrders, body: ContractReference(symbol: symbol))
    }

    /// Returns a page of historical orders.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field holds the orders.
    public func orderHistory(_ query: OrderHistoryQuery = OrderHistoryQuery()) async throws(MexcFuturesError) -> JSON {
        try await get(.orderHistory, query: query.queryItems)
    }

    /// Returns a page of order executions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field holds the executions.
    public func orderDeals(_ query: OrderDealsQuery) async throws(MexcFuturesError) -> JSON {
        try await get(.orderDeals, query: query.queryItems)
    }

    /// Returns the order with an identifier.
    ///
    /// - Parameter id: The identifier of the order.
    /// - Returns: The response body, whose `data` field holds the order.
    public func order(id: Int64) async throws(MexcFuturesError) -> JSON {
        try await get(.order, pathComponents: [String(id)])
    }

    /// Returns the order with a client-assigned identifier.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol of the order.
    ///   - externalOrderID: The client-assigned identifier of the order.
    /// - Returns: The response body, whose `data` field holds the order.
    public func order(symbol: String, externalOrderID: String) async throws(MexcFuturesError) -> JSON {
        try await get(.orderByExternalID, pathComponents: [symbol, externalOrderID])
    }

    /// Returns the risk limits of the account.
    ///
    /// - Returns: The response body, whose `data` field lists the risk limit of each contract.
    public func riskLimits() async throws(MexcFuturesError) -> JSON {
        try await get(.riskLimit)
    }

    /// Returns the trading fee rates of the account.
    ///
    /// - Returns: The response body, whose `data` field lists the fee rates of each contract.
    public func feeRates() async throws(MexcFuturesError) -> JSON {
        try await get(.feeRate)
    }

    /// Returns the balance of one currency.
    ///
    /// - Parameter currency: The currency, such as `USDT`.
    /// - Returns: The response body, whose `data` field holds the balance.
    public func accountAsset(currency: String) async throws(MexcFuturesError) -> JSON {
        try await get(.accountAsset, pathComponents: [currency])
    }

    /// Returns the open positions.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for the positions of every contract.
    /// - Returns: The response body, whose `data` field lists the positions.
    public func openPositions(symbol: String? = nil) async throws(MexcFuturesError) -> JSON {
        try await get(.openPositions, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
    }

    /// Returns a page of closed positions.
    ///
    /// - Parameter query: The filters and page to return.
    /// - Returns: The response body, whose `data` field lists the positions.
    public func positionHistory(_ query: PositionHistoryQuery = PositionHistoryQuery()) async throws(MexcFuturesError) -> JSON {
        try await get(.positionHistory, query: query.queryItems)
    }

    /// Returns the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    /// - Returns: The response body, whose `data` field holds the ticker.
    public func ticker(symbol: String) async throws(MexcFuturesError) -> JSON {
        try await get(.ticker, query: [URLQueryItem(name: "symbol", value: symbol)])
    }

    /// Returns the specification of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for every contract.
    /// - Returns: The response body, whose `data` field holds one contract, or an array of every contract.
    public func contractDetail(symbol: String? = nil) async throws(MexcFuturesError) -> JSON {
        try await get(.contractDetail, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
    }

    /// Returns the order book of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - limit: The number of price levels per side, or `nil` for the server default.
    /// - Returns: The response body, holding the `asks` and `bids` price levels.
    public func contractDepth(symbol: String, limit: Int? = nil) async throws(MexcFuturesError) -> JSON {
        try await get(.contractDepth, pathComponents: [symbol], query: limit.map { [URLQueryItem(name: "limit", value: String($0))] } ?? [])
    }

    /// Checks that the API is reachable by requesting the `BTC_USDT` ticker.
    ///
    /// - Returns: `true` when the request succeeds.
    public func testConnection() async -> Bool {
        do {
            _ = try await ticker(symbol: "BTC_USDT")
            return true
        } catch {
            return false
        }
    }
}

private struct ExternalOrderReference: Encodable {
    let symbol: String
    let externalOid: String
}

private struct ContractReference: Encodable {
    let symbol: String?
}

extension MexcFuturesClient {
    private func get(
        _ endpoint: Endpoint,
        pathComponents: [String] = [],
        query: [URLQueryItem] = []
    ) async throws(MexcFuturesError) -> JSON {
        let request = makeRequest(method: "GET", endpoint: endpoint, pathComponents: pathComponents, query: query)
        return try await send(request)
    }

    private func post(_ endpoint: Endpoint, body: some Encodable) async throws(MexcFuturesError) -> JSON {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw .validation(message: "Request body could not be encoded: \(error.localizedDescription)", field: nil)
        }
        let signature = RequestSignature(
            body: String(decoding: data, as: UTF8.self),
            authToken: configuration.authToken,
            timestamp: String(Date.now.millisecondsSince1970)
        )
        var request = makeRequest(method: "POST", endpoint: endpoint)
        request.setValue(signature.nonce, forHTTPHeaderField: "x-mxc-nonce")
        request.setValue(signature.sign, forHTTPHeaderField: "x-mxc-sign")
        request.httpBody = data
        logger.debug("Request body", metadata: ["body": "\(String(decoding: data, as: UTF8.self))"])
        return try await send(request)
    }

    private func makeRequest(
        method: String,
        endpoint: Endpoint,
        pathComponents: [String] = [],
        query: [URLQueryItem] = []
    ) -> URLRequest {
        var url = configuration.baseURL.appending(path: endpoint.rawValue)
        for component in pathComponents {
            url.append(component: component)
        }
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout / .seconds(1))
        request.httpMethod = method
        var headers = Self.defaultHeaders
        if let userAgent = configuration.userAgent {
            headers["user-agent"] = userAgent
        }
        headers.merge(configuration.customHeaders) { $1 }
        headers["authorization"] = configuration.authToken
        request.allHTTPHeaderFields = headers
        return request
    }

    private func send(_ request: URLRequest) async throws(MexcFuturesError) -> JSON {
        let method = request.httpMethod ?? "GET"
        let endpoint = request.url.map { String($0.path().trimmingPrefix(configuration.baseURL.path())) } ?? ""
        logger.debug("Sending request", metadata: ["method": "\(method)", "url": "\(request.url?.absoluteString ?? "")"])

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.response(for: request)
        } catch let error as URLError {
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw .network(error)
        } catch {
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw .unknown(message: error.localizedDescription)
        }

        let body = JSON(responseData: data)
        logger.debug("Received response", metadata: ["status": "\(response.statusCode)"])
        guard (200..<300).contains(response.statusCode) else {
            let error = MexcFuturesError(response: response, body: body, method: method, endpoint: endpoint)
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw error
        }
        return body
    }
}

extension MexcFuturesError {
    init(response: HTTPURLResponse, body: JSON, method: String, endpoint: String) {
        let statusCode = response.statusCode
        let message = body["message"].stringValue.isEmpty ? "Request failed with status code \(statusCode)" : body["message"].stringValue
        let code = body["code"].intValue == 0 ? statusCode : body["code"].intValue

        switch statusCode {
        case 401:
            self = .authentication(message: message)
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init).map(Duration.seconds)
            self = .rateLimit(message: message, retryAfter: retryAfter)
        case _ where code == 602 || message.contains("signature") || message.contains("Signature"):
            self = .signature(message: message)
        default:
            self = .api(message: message, code: code, statusCode: statusCode, method: method, endpoint: endpoint, response: body)
        }
    }
}

extension JSON {
    init(responseData data: Data) {
        self = (try? JSON(data: data)) ?? JSON(String(decoding: data, as: UTF8.self))
    }
}
