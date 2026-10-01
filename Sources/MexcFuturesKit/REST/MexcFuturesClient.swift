public import Foundation
public import Logging

/// A client for the MEXC futures REST API.
///
/// The client serves public market data, which needs no credentials. Private account data and
/// trading need a WEB token, see ``account(authToken:)``.
///
/// Every method returns MEXC's whole ``Response``, including whether the request succeeded:
///
/// ```swift
/// let client = MexcFuturesClient()
/// let response = try await client.ticker(symbol: "BTC_USDT")
/// print(response.data?.lastPrice ?? 0)
/// ```
public struct MexcFuturesClient: Sendable {
    /// The settings of the client.
    public let configuration: Configuration

    let transport: any HTTPTransport
    let logger: Logger

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - configuration: The settings of the client.
    ///   - session: The URL session that performs the requests.
    ///   - logger: The logger that records requests and responses.
    public init(
        configuration: Configuration = Configuration(),
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

    /// Returns a client for the private account and trading endpoints.
    ///
    /// - Parameter authToken: The WEB authorization token of a signed-in browser session.
    ///   Copy the `authorization` header, which starts with `WEB`, from any request to
    ///   `futures.mexc.com` in the browser's developer tools.
    /// - Returns: A client that authenticates every request with `authToken`.
    public func account(authToken: String) -> Account {
        Account(client: self, authToken: authToken)
    }
}

extension MexcFuturesClient {
    /// Returns the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    /// - Returns: The response, whose ``Response/data`` holds the ticker.
    public func ticker(symbol: String) async throws(MexcFuturesError) -> Response<Ticker> {
        try await get(.ticker, query: [URLQueryItem(name: "symbol", value: symbol)])
            .decode { Response(node: $0, payload: Ticker.init(node:)) }
    }

    /// Returns the specification of a contract, or of every contract.
    ///
    /// - Parameter symbol: The contract symbol, or `nil` for every contract.
    /// - Returns: The response, whose ``Response/data`` holds the requested contracts.
    public func contractDetail(symbol: String? = nil) async throws(MexcFuturesError) -> Response<[ContractDetail]> {
        try await get(.contractDetail, query: symbol.map { [URLQueryItem(name: "symbol", value: $0)] } ?? [])
            .decode { root in
                Response(node: root) { data in
                    data.map(ContractDetail.init(node:)) ?? (data.isObject ? [ContractDetail(node: data)] : nil)
                }
            }
    }

    /// Returns the order book of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - limit: The number of price levels per side, or `nil` for the server default.
    /// - Returns: The response, whose ``Response/data`` holds the order book.
    public func contractDepth(symbol: String, limit: Int? = nil) async throws(MexcFuturesError) -> Response<ContractDepth> {
        try await get(.contractDepth, pathComponents: [symbol], query: limit.map { [URLQueryItem(name: "limit", value: String($0))] } ?? [])
            .decode { root in
                root["data"].exists
                    ? Response(node: root, payload: ContractDepth.init(node:))
                    : Response(success: true, code: 0, message: nil, data: ContractDepth(node: root))
            }
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
