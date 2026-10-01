import Foundation
public import Logging
import NIOCore
import NIOPosix
import NIOWebSocket
import SwiftyJSON
import WebSocketKit

/// A client for the MEXC futures WebSocket API.
///
/// The socket delivers market data, private account data and connection changes as ``Event`` values:
///
/// ```swift
/// let socket = MexcFuturesWebSocket(configuration: .init(apiKey: "...", secretKey: "..."))
/// let events = socket.events()
/// try await socket.connect()
/// try await socket.subscribeToTicker(symbol: "BTC_USDT")
///
/// for await event in events {
///     if case .ticker(let ticker) = event {
///         print(ticker["lastPrice"].doubleValue)
///     }
/// }
/// ```
///
/// The socket sends keep-alive pings while connected and, when ``Configuration/autoReconnect`` is on,
/// reconnects after the connection drops.
public actor MexcFuturesWebSocket {
    /// The settings of the socket.
    public let configuration: Configuration

    /// Whether the session is logged in and receives private data.
    public private(set) var isLoggedIn = false

    private static let url = URL(string: "wss://contract.mexc.com/edge")!

    private let logger: Logger
    private let broadcaster = EventBroadcaster<Event>()
    private var state = State.disconnected
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    /// Creates a socket without opening the connection.
    ///
    /// - Parameters:
    ///   - configuration: The settings of the socket.
    ///   - logger: The logger that records connection changes and messages.
    public init(configuration: Configuration, logger: Logger = Logger(label: "MexcFuturesKit")) {
        self.configuration = configuration
        self.logger = logger
    }

    deinit {
        pingTask?.cancel()
        reconnectTask?.cancel()
        if case .connected(let socket) = state {
            _ = socket.close(code: .goingAway)
        }
    }

    /// Whether the connection is open.
    public var isConnected: Bool {
        if case .connected = state { true } else { false }
    }

    /// Returns a stream of the events delivered after this call.
    ///
    /// Every stream receives every event, so several tasks can observe the socket at once.
    /// A stream finishes when the socket is deallocated or the iterating task is cancelled.
    ///
    /// - Parameter bufferingPolicy: The policy for events that arrive faster than they are consumed.
    /// - Returns: A stream of socket events.
    public nonisolated func events(
        bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .unbounded
    ) -> AsyncStream<Event> {
        broadcaster.makeStream(bufferingPolicy: bufferingPolicy)
    }

    /// Opens the connection.
    ///
    /// Does nothing when the connection is already open or opening.
    public func connect() async throws(MexcFuturesError) {
        guard case .disconnected = state else { return }
        state = .connecting
        logger.debug("Connecting to MEXC Futures WebSocket")

        let (frames, continuation) = AsyncStream.makeStream(of: Frame.self)
        let socket: WebSocket
        do {
            socket = try await Self.open(Self.url, forwardingFramesTo: continuation)
        } catch {
            continuation.finish()
            state = .disconnected
            logger.error("WebSocket connection failed", metadata: ["error": "\(error)"])
            broadcaster.yield(.error(.connectionFailed(error)))
            throw .connectionFailed(error)
        }

        guard case .connecting = state else {
            try? await socket.close()
            return
        }
        state = .connected(socket)
        logger.debug("WebSocket connected")
        receive(frames, from: socket)
        startPinging()
        broadcaster.yield(.connected)
    }

    /// Closes the connection and cancels any pending reconnection.
    public func disconnect() async {
        logger.debug("Disconnecting from MEXC Futures WebSocket")
        reconnectTask?.cancel()
        reconnectTask = nil
        stopPinging()
        isLoggedIn = false
        let socket: WebSocket? = if case .connected(let socket) = state { socket } else { nil }
        state = .disconnected
        try? await socket?.close()
    }

    /// Logs in with the configured API key to receive private data.
    ///
    /// The ``Event/login(_:)`` event confirms the login, after which ``isLoggedIn`` is `true`.
    ///
    /// - Parameter subscribe: Whether the server pushes every kind of private data after login.
    ///   Pass `false` to choose the data with ``setPersonalFilter(_:)``.
    public func login(subscribe: Bool = true) async throws(MexcFuturesError) {
        guard isConnected else { throw .notConnected }
        let requestTime = String(Date.now.millisecondsSince1970)
        try await send([
            "subscribe": subscribe,
            "method": "login",
            "param": [
                "apiKey": configuration.apiKey,
                "signature": hmacSHA256(configuration.apiKey + requestTime, secret: configuration.secretKey),
                "reqTime": requestTime,
            ],
        ])
    }

    /// Selects the private data the server pushes.
    ///
    /// - Parameter filters: The kinds of private data to receive, or an empty array for every kind.
    public func setPersonalFilter(_ filters: [PersonalFilter] = []) async throws(MexcFuturesError) {
        guard isLoggedIn else { throw .notLoggedIn }
        try await send(["method": "personal.filter", "param": ["filters": filters.map(\.json)]])
    }

    /// Receives only order updates.
    ///
    /// - Parameter symbols: The contract symbols to receive updates for, or `nil` for every contract.
    public func subscribeToOrders(symbols: [String]? = nil) async throws(MexcFuturesError) {
        try await setPersonalFilter([PersonalFilter(.order, symbols: symbols)])
    }

    /// Receives only order executions.
    ///
    /// - Parameter symbols: The contract symbols to receive executions for, or `nil` for every contract.
    public func subscribeToOrderDeals(symbols: [String]? = nil) async throws(MexcFuturesError) {
        try await setPersonalFilter([PersonalFilter(.orderDeal, symbols: symbols)])
    }

    /// Receives only position updates.
    ///
    /// - Parameter symbols: The contract symbols to receive updates for, or `nil` for every contract.
    public func subscribeToPositions(symbols: [String]? = nil) async throws(MexcFuturesError) {
        try await setPersonalFilter([PersonalFilter(.position, symbols: symbols)])
    }

    /// Receives only balance updates.
    public func subscribeToAssets() async throws(MexcFuturesError) {
        try await setPersonalFilter([PersonalFilter(.asset)])
    }

    /// Receives only auto-deleveraging level updates.
    public func subscribeToADLLevels() async throws(MexcFuturesError) {
        try await setPersonalFilter([PersonalFilter(.adlLevel)])
    }

    /// Receives every kind of private data.
    public func subscribeToAll() async throws(MexcFuturesError) {
        try await setPersonalFilter([])
    }

    /// Subscribes to the tickers of every contract.
    ///
    /// - Parameter gzip: Whether the server compresses the pushed data.
    public func subscribeToAllTickers(gzip: Bool = false) async throws(MexcFuturesError) {
        try await send(["method": "sub.tickers", "param": [String: String](), "gzip": gzip])
    }

    /// Unsubscribes from the tickers of every contract.
    public func unsubscribeFromAllTickers() async throws(MexcFuturesError) {
        try await send(["method": "unsub.tickers", "param": [String: String]()])
    }

    /// Subscribes to the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToTicker(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.ticker", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the ticker of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromTicker(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.ticker", "param": ["symbol": symbol]])
    }

    /// Subscribes to the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToDeals(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.deal", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the trades of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDeals(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.deal", "param": ["symbol": symbol]])
    }

    /// Subscribes to incremental order book updates of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - compress: Whether the server merges updates before pushing them.
    public func subscribeToDepth(symbol: String, compress: Bool = false) async throws(MexcFuturesError) {
        try await send(["method": "sub.depth", "param": ["symbol": symbol, "compress": compress]])
    }

    /// Unsubscribes from incremental order book updates of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromDepth(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.depth", "param": ["symbol": symbol]])
    }

    /// Subscribes to full order book snapshots of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - limit: The number of price levels per side.
    public func subscribeToFullDepth(symbol: String, limit: DepthLimit = .twenty) async throws(MexcFuturesError) {
        try await send(["method": "sub.depth.full", "param": ["symbol": symbol, "limit": limit.rawValue]])
    }

    /// Unsubscribes from full order book snapshots of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFullDepth(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.depth.full", "param": ["symbol": symbol]])
    }

    /// Subscribes to the candles of a contract.
    ///
    /// - Parameters:
    ///   - symbol: The contract symbol, such as `BTC_USDT`.
    ///   - interval: The candle interval.
    public func subscribeToKline(symbol: String, interval: KlineInterval) async throws(MexcFuturesError) {
        try await send(["method": "sub.kline", "param": ["symbol": symbol, "interval": interval.rawValue]])
    }

    /// Unsubscribes from the candles of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromKline(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.kline", "param": ["symbol": symbol]])
    }

    /// Subscribes to the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.funding.rate", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the funding rate of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFundingRate(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.funding.rate", "param": ["symbol": symbol]])
    }

    /// Subscribes to the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.index.price", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the index price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromIndexPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.index.price", "param": ["symbol": symbol]])
    }

    /// Subscribes to the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func subscribeToFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "sub.fair.price", "param": ["symbol": symbol]])
    }

    /// Unsubscribes from the fair price of a contract.
    ///
    /// - Parameter symbol: The contract symbol, such as `BTC_USDT`.
    public func unsubscribeFromFairPrice(symbol: String) async throws(MexcFuturesError) {
        try await send(["method": "unsub.fair.price", "param": ["symbol": symbol]])
    }
}

extension MexcFuturesWebSocket {
    private enum State {
        case disconnected
        case connecting
        case connected(WebSocket)
    }

    private enum Frame: Sendable {
        case text(String)
        case closed(code: Int?)
    }

    private static func open(
        _ url: URL,
        forwardingFramesTo frames: AsyncStream<Frame>.Continuation
    ) async throws -> WebSocket {
        try await withCheckedThrowingContinuation { continuation in
            WebSocket.connect(to: url, on: MultiThreadedEventLoopGroup.singleton) { socket in
                socket.onText { _, text in
                    frames.yield(.text(text))
                }
                socket.onBinary { _, buffer in
                    frames.yield(.text(String(buffer: buffer)))
                }
                socket.onClose.whenComplete { _ in
                    frames.yield(.closed(code: socket.closeCode.map { Int(UInt16(webSocketErrorCode: $0)) }))
                    frames.finish()
                }
                continuation.resume(returning: socket)
            }.whenFailure { error in
                continuation.resume(throwing: error)
            }
        }
    }

    private func receive(_ frames: AsyncStream<Frame>, from socket: WebSocket) {
        Task(name: "MexcFuturesWebSocket.receive") { [weak self] in
            for await frame in frames {
                await self?.handle(frame, from: socket)
            }
        }
    }

    private func handle(_ frame: Frame, from socket: WebSocket) {
        switch frame {
        case .text(let text):
            receive(text)
        case .closed(let code):
            handleClose(of: socket, code: code)
        }
    }

    func receive(_ text: String) {
        logger.trace("Received WebSocket message", metadata: ["message": "\(text)"])
        guard let message = try? JSON(data: Data(text.utf8)) else {
            logger.error("Malformed WebSocket message", metadata: ["message": "\(text)"])
            broadcaster.yield(.error(.malformedMessage(text)))
            return
        }

        let event = Event(message: message)
        switch event {
        case .login:
            isLoggedIn = true
            logger.debug("WebSocket login succeeded")
        case .loginFailed(let response):
            isLoggedIn = false
            logger.error("WebSocket login failed", metadata: ["response": "\(response)"])
        case .filterSet:
            logger.debug("Personal filter set")
        case .filterFailed(let response):
            logger.error("Personal filter rejected", metadata: ["response": "\(response)"])
        case .subscribed(let channel, _):
            logger.debug("Subscribed", metadata: ["channel": "\(channel)"])
        case .unsubscribed(let channel, _):
            logger.debug("Unsubscribed", metadata: ["channel": "\(channel)"])
        case .error(let error):
            logger.error("WebSocket error response", metadata: ["error": "\(error.localizedDescription)"])
        default:
            break
        }
        broadcaster.yield(event)
    }

    private func handleClose(of socket: WebSocket, code: Int?) {
        let isCurrentSocket = if case .connected(let current) = state { current === socket } else { false }
        if isCurrentSocket {
            logger.warning("WebSocket closed", metadata: ["code": "\(code.map(String.init) ?? "none")"])
            state = .disconnected
            isLoggedIn = false
            stopPinging()
        }
        broadcaster.yield(.disconnected(code: code))
        if isCurrentSocket, configuration.autoReconnect {
            scheduleReconnect()
        }
    }

    private func send(_ message: JSON) async throws(MexcFuturesError) {
        guard case .connected(let socket) = state else {
            logger.debug("Cannot send message: WebSocket not connected")
            throw .notConnected
        }
        guard let data = try? message.rawData(options: [.sortedKeys, .withoutEscapingSlashes]) else {
            throw .unknown(message: "WebSocket message could not be encoded")
        }
        let text = String(decoding: data, as: UTF8.self)

        var loggedMessage = message
        if message["method"].string == "login" {
            loggedMessage["param"] = "[REDACTED]"
        }
        logger.debug("Sending WebSocket message", metadata: ["message": "\(loggedMessage.rawString(options: []) ?? "")"])

        do {
            try await socket.send(text)
        } catch {
            throw .connectionFailed(error)
        }
    }

    private func startPinging() {
        stopPinging()
        let interval = configuration.pingInterval
        pingTask = Task(name: "MexcFuturesWebSocket.ping") { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                guard let self else { return }
                await self.ping()
            }
        }
    }

    private func stopPinging() {
        pingTask?.cancel()
        pingTask = nil
    }

    private func ping() async {
        logger.trace("Sending ping")
        try? await send(["method": "ping"])
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let interval = configuration.reconnectInterval
        logger.debug("Scheduling reconnect", metadata: ["delay": "\(interval)"])
        reconnectTask = Task(name: "MexcFuturesWebSocket.reconnect") { [weak self] in
            repeat {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
            } while await self?.reconnect() == false
        }
    }

    private func reconnect() async -> Bool {
        logger.debug("Reconnecting to MEXC Futures WebSocket")
        do {
            try await connect()
            return true
        } catch {
            return false
        }
    }
}
