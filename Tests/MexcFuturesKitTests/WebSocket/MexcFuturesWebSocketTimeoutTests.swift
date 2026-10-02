import Foundation
import NIOCore
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesWebSocket timeouts and cancellation", .tags(.networking), .timeLimit(.minutes(1)))
struct MexcFuturesWebSocketTimeoutTests {
    @Test func connectTimesOutWhenUpgradeStalls() async throws {
        let server = try await MockMexcServer.start(behavior: .init(upgradeDelay: .seconds(2)))
        let socket = MexcFuturesWebSocket(configuration: .init(url: server.url, autoReconnect: false, timeout: .milliseconds(200)))

        let error = try await #require(throws: MexcFuturesError.self) {
            try await socket.connect()
        }

        guard case .connectionFailed(let underlying) = error else {
            Issue.record("Expected a connection failure, got \(error)")
            return
        }
        #expect((underlying as? URLError)?.code == .timedOut)
        #expect(await socket.isConnected == false)
        await server.shutdown()
    }

    @Test func loginTimesOutWithoutAnswer() async throws {
        try await withConnectedSocket(
            behavior: .init(answersLogin: false),
            configuration: { .init(url: $0, autoReconnect: false, timeout: .seconds(1)) }
        ) { _, socket, _ in
            let error = try await #require(throws: MexcFuturesError.self) {
                try await socket.login(authToken: "WEB-token")
            }

            guard case .connectionFailed(let underlying) = error else {
                Issue.record("Expected a connection failure, got \(error)")
                return
            }
            #expect((underlying as? URLError)?.code == .timedOut)
            #expect(await socket.isLoggedIn == false)
        }
    }

    @Test func disconnectCancelsPendingConnect() async throws {
        let server = try await MockMexcServer.start(behavior: .init(upgradeDelay: .milliseconds(500)))
        let socket = MexcFuturesWebSocket(configuration: .init(url: server.url, autoReconnect: false))
        let connecting = Task { try await socket.connect() }
        while server.handshakes.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        await socket.disconnect()

        let result = await connecting.result
        guard case .failure(MexcFuturesError.cancelled) = result else {
            Issue.record("Expected a cancelled connect, got \(result)")
            await server.shutdown()
            return
        }
        #expect(await socket.isConnected == false)
        await server.shutdown()
    }
}
