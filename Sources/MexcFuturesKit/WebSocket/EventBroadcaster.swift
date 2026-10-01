import Foundation
import Synchronization

final class EventBroadcaster<Element: Sendable>: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<Element>.Continuation]>([:])

    func makeStream(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy) -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { $0[id] = nil }
        }
        continuations.withLock { $0[id] = continuation }
        return stream
    }

    func yield(_ element: Element) {
        for continuation in continuations.withLock({ Array($0.values) }) {
            continuation.yield(element)
        }
    }

    deinit {
        continuations.withLock { continuations in
            for continuation in continuations.values {
                continuation.finish()
            }
        }
    }
}
