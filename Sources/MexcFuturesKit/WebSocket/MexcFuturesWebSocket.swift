import Foundation
public import Logging
import NIOCore
import NIOPosix
import NIOWebSocket
import WebSocketKit

/// A client for the MEXC futures WebSocket API.
///
/// The socket delivers market data, private account data and connection changes as ``Event`` values.
/// Market data needs no credentials:
///
/// ```swift
/// let socket = MexcFuturesWebSocket()
/// let events = socket.events()
/// try await socket.connect()
/// try await socket.subscribeToTicker(symbol: "BTC_USDT")
///
/// for await event in events {
///     if case .ticker(let ticker) = event {
///         print(ticker.lastPrice)
///     }
/// }
/// ```
///
/// Private account data needs a login with the WEB token, ``login(authToken:subscribe:)``, or an API key.
/// The login returns an ``Account`` that selects the private data the server pushes.
///
/// The socket sends keep-alive pings while connected and, when ``Configuration/autoReconnect`` is on,
/// reconnects after the connection drops.
public actor MexcFuturesWebSocket {
    /// The settings of the socket.
    public let configuration: Configuration

    /// Whether the session is logged in and receives private data.
    public private(set) var isLoggedIn = false

    let logger: Logger
    let broadcaster = EventBroadcaster<Event>()
    var session = Session()
    private var state = State.disconnected
    private var connectionAttempt = 0
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    /// Creates a socket without opening the connection.
    ///
    /// - Parameters:
    ///   - configuration: The settings of the socket.
    ///   - logger: The logger that records connection changes and messages.
    public init(configuration: Configuration = Configuration(), logger: Logger = Logger(label: "MexcFuturesKit")) {
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

    /// Calls a handler with every event delivered after this call.
    ///
    /// The handler runs as each event is delivered. Market and account data reach it on the network
    /// thread that received the message, with no hand-off to another task, so a handler is the lowest
    /// latency way to consume the socket. Calls never overlap. Keep the handler short: the socket
    /// handles no further messages until it returns.
    ///
    /// - Parameter handler: The closure that receives each event.
    public nonisolated func onEvent(_ handler: @escaping @Sendable (Event) -> Void) {
        broadcaster.addHandler(handler)
    }

    /// Opens the connection.
    ///
    /// When an earlier connection dropped, the socket first logs in again, re-applies the personal filter
    /// and re-subscribes to market data, then delivers ``Event/connected``.
    /// Does nothing when the connection is already open or opening.
    ///
    /// - Throws: ``MexcFuturesError/connectionFailed(_:)`` when the connection fails or the server does not
    ///   answer within ``Configuration/timeout``, ``MexcFuturesError/cancelled`` when ``disconnect()`` runs
    ///   before the connection opens, and ``MexcFuturesError/notConnected`` when the connection closes
    ///   while the session is restored.
    public func connect() async throws(MexcFuturesError) {
        guard case .disconnected = state else { return }
        connectionAttempt += 1
        let attempt = connectionAttempt
        state = .connecting
        logger.debug("Connecting to MEXC Futures WebSocket")

        let (frames, continuation) = AsyncStream.makeStream(of: Frame.self)
        let router = MessageRouter(logger: logger, broadcaster: broadcaster, frames: continuation)
        let socket: WebSocket
        do {
            socket = try await Self.open(configuration.url, timeout: configuration.timeout, routingTo: router)
        } catch {
            continuation.finish()
            if isConnecting(attempt) {
                state = .disconnected
            }
            if error is CancellationError {
                throw .cancelled
            }
            logger.error("WebSocket connection failed", metadata: ["error": "\(error)"])
            broadcaster.yield(.error(.connectionFailed(error)))
            throw .connectionFailed(error)
        }

        guard isConnecting(attempt) else {
            try? await socket.close()
            throw .cancelled
        }
        state = .connected(socket)
        logger.debug("WebSocket connected")
        receive(frames, from: socket)
        startPinging()
        await restoreSession()
        guard isCurrent(socket) else { throw .notConnected }
        broadcaster.yield(.connected)
    }

    /// Closes the connection, cancels any pending reconnection, and forgets the login and subscriptions.
    public func disconnect() async {
        logger.debug("Disconnecting from MEXC Futures WebSocket")
        reconnectTask?.cancel()
        reconnectTask = nil
        stopPinging()
        isLoggedIn = false
        session = Session()
        let socket: WebSocket? = if case .connected(let socket) = state { socket } else { nil }
        state = .disconnected
        guard let socket else { return }
        try? await socket.close()
        broadcaster.yield(.disconnected(code: socket.closeCode.map { Int(UInt16(webSocketErrorCode: $0)) }))
    }
}

extension MexcFuturesWebSocket {
    private enum State {
        case disconnected
        case connecting
        case connected(WebSocket)
    }

    private enum Frame: Sendable {
        case sessionEvent(Event)
        case closed(code: Int?)
    }

    private struct MessageRouter: Sendable {
        let logger: Logger
        let broadcaster: EventBroadcaster<Event>
        let frames: AsyncStream<Frame>.Continuation

        func route(_ text: String) {
            logger.trace("Received WebSocket message", metadata: ["message": "\(text)"])
            let event = Event(text: text)
            switch event {
            case .login, .loginFailed:
                frames.yield(.sessionEvent(event))
                return
            case .filterSet:
                logger.debug("Personal filter set")
            case .filterFailed(let response):
                logger.error("Personal filter rejected", metadata: ["response": "\(response)"])
            case .subscribed(let channel, _):
                logger.debug("Subscribed", metadata: ["channel": "\(channel)"])
            case .unsubscribed(let channel, _):
                logger.debug("Unsubscribed", metadata: ["channel": "\(channel)"])
            case .error(let error):
                logger.error("WebSocket error", metadata: ["error": "\(error.localizedDescription)"])
            default:
                break
            }
            broadcaster.yield(event)
        }
    }

    private static func open(_ url: URL, timeout: Duration, routingTo router: MessageRouter) async throws -> WebSocket {
        let eventLoop = MultiThreadedEventLoopGroup.singleton.next()
        let opened = eventLoop.makePromise(of: WebSocket.self)
        let timer = eventLoop.scheduleTask(in: TimeAmount(timeout)) {
            opened.fail(URLError(.timedOut))
        }
        opened.futureResult.whenComplete { _ in
            timer.cancel()
        }
        WebSocket.connect(to: url, on: eventLoop) { socket in
            socket.onText { _, text in
                router.route(text)
            }
            socket.onBinary { _, buffer in
                router.route(String(buffer: buffer))
            }
            socket.onClose.whenComplete { _ in
                router.frames.yield(.closed(code: socket.closeCode.map { Int(UInt16(webSocketErrorCode: $0)) }))
                router.frames.finish()
            }
            opened.succeed(socket)
            opened.futureResult.whenFailure { _ in
                _ = socket.close(code: .goingAway)
            }
        }.whenFailure { error in
            opened.fail(error)
        }
        return try await withTaskCancellationHandler {
            try await opened.futureResult.get()
        } onCancel: {
            opened.fail(CancellationError())
        }
    }

    private func isConnecting(_ attempt: Int) -> Bool {
        if case .connecting = state { attempt == connectionAttempt } else { false }
    }

    private func isCurrent(_ socket: WebSocket) -> Bool {
        if case .connected(let current) = state { current === socket } else { false }
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
        case .sessionEvent(let event):
            guard isCurrent(socket) else { return }
            if case .loginFailed(let response) = event {
                isLoggedIn = false
                logger.error("WebSocket login failed", metadata: ["response": "\(response)"])
            } else {
                isLoggedIn = true
                logger.debug("WebSocket login succeeded")
            }
            broadcaster.yield(event)
        case .closed(let code):
            handleClose(of: socket, code: code)
        }
    }

    private func handleClose(of socket: WebSocket, code: Int?) {
        guard isCurrent(socket) else { return }
        logger.warning("WebSocket closed", metadata: ["code": "\(code.map(String.init) ?? "none")"])
        state = .disconnected
        isLoggedIn = false
        stopPinging()
        broadcaster.yield(.disconnected(code: code))
        if configuration.autoReconnect {
            scheduleReconnect()
        }
    }

    func send(_ message: [String: Any]) async throws(MexcFuturesError) {
        guard case .connected(let socket) = state else {
            logger.debug("Cannot send message: WebSocket not connected")
            throw .notConnected
        }
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            throw .unknown(message: "WebSocket message could not be encoded")
        }
        let text = String(decoding: data, as: UTF8.self)
        logger.debug("Sending WebSocket message", metadata: ["message": "\(message["method"] as? String == "login" ? "login" : text)"])

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
