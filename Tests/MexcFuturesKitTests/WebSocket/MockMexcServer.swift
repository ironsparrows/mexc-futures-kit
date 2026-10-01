import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import Synchronization
import WebSocketKit
@testable import MexcFuturesKit

final class MockMexcServer: Sendable {
    struct Behavior: Sendable {
        var acceptsLogin = true
    }

    let messages: AsyncStream<JSON>
    private let messageContinuation: AsyncStream<JSON>.Continuation
    private let state: Mutex<(handshakes: [HTTPHeaders], sockets: [WebSocket])>
    private let behavior: Behavior
    private let channel: Mutex<(any Channel)?>

    private init(behavior: Behavior) {
        (messages, messageContinuation) = AsyncStream.makeStream(of: JSON.self)
        state = Mutex(([], []))
        channel = Mutex(nil)
        self.behavior = behavior
    }

    static func start(behavior: Behavior = Behavior()) async throws -> MockMexcServer {
        let server = MockMexcServer(behavior: behavior)
        let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .childChannelInitializer { channel in
                let upgrader = NIOWebSocketServerUpgrader(
                    shouldUpgrade: { channel, head in
                        server.state.withLock { $0.handshakes.append(head.headers) }
                        return channel.eventLoop.makeSucceededFuture([:])
                    },
                    upgradePipelineHandler: { channel, _ in
                        WebSocket.server(on: channel) { socket in
                            server.accept(socket)
                        }
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in })
                )
            }
            .bind(host: "127.0.0.1", port: 0)
            .get()
        server.channel.withLock { $0 = channel }
        return server
    }

    var url: URL {
        let port = channel.withLock { $0?.localAddress?.port ?? 0 }
        return URL(string: "ws://127.0.0.1:\(port)/edge")!
    }

    var handshakes: [HTTPHeaders] {
        state.withLock { $0.handshakes }
    }

    func send(binary bytes: [UInt8]) async throws {
        for socket in state.withLock({ $0.sockets }) {
            try await socket.send(bytes)
        }
    }

    func send(_ message: [String: Any]) async throws {
        try await send(text: String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self))
    }

    func send(text: String) async throws {
        for socket in state.withLock({ $0.sockets }) {
            try await socket.send(text)
        }
    }

    func dropConnections() async {
        let sockets = state.withLock { state in
            defer { state.sockets.removeAll() }
            return state.sockets
        }
        for socket in sockets {
            try? await socket.close(code: .goingAway)
        }
    }

    func shutdown() async {
        await dropConnections()
        messageContinuation.finish()
        try? await channel.withLock({ $0 })?.close()
    }

    func nextMessage(method: String) async -> JSON? {
        for await message in messages where message["method"].string == method {
            return message
        }
        return nil
    }

    func methods(until required: Set<String>) async -> [String] {
        var seen: [String] = []
        for await message in messages {
            seen.append(message["method"].stringValue)
            if required.isSubset(of: seen) {
                break
            }
        }
        return seen
    }

    private func accept(_ socket: WebSocket) {
        state.withLock { $0.sockets.append(socket) }
        socket.onText { socket, text in
            guard let message = try? JSON(data: Data(text.utf8)) else { return }
            self.messageContinuation.yield(message)
            if let reply = self.reply(to: message), let data = try? JSONSerialization.data(withJSONObject: reply) {
                socket.send(String(decoding: data, as: UTF8.self))
            }
        }
    }

    private func reply(to message: JSON) -> [String: Any]? {
        let method = message["method"].stringValue
        return switch method {
        case "ping":
            ["channel": "pong", "data": 1_700_000_000_000]
        case "login":
            ["channel": "rs.login", "data": behavior.acceptsLogin ? "success" : "failed"]
        case "personal.filter":
            ["channel": "rs.personal.filter", "data": "success"]
        case _ where method.hasPrefix("sub.") || method.hasPrefix("unsub."):
            ["channel": "rs.\(method)", "data": "success"]
        default:
            nil
        }
    }
}
