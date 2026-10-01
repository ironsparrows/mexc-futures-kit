import Foundation
import Synchronization

final class EventBroadcaster<Element: Sendable>: Sendable {
    private struct Listeners {
        var handlers: [@Sendable (Element) -> Void] = []
        var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]
    }

    private let listeners = Mutex(Listeners())

    func addHandler(_ handler: @escaping @Sendable (Element) -> Void) {
        listeners.withLock { $0.handlers.append(handler) }
    }

    func makeStream(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy) -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.listeners.withLock { $0.continuations[id] = nil }
        }
        listeners.withLock { $0.continuations[id] = continuation }
        return stream
    }

    func yield(_ element: Element) {
        listeners.withLock { listeners in
            for handler in listeners.handlers {
                handler(element)
            }
            for continuation in listeners.continuations.values {
                continuation.yield(element)
            }
        }
    }

    deinit {
        listeners.withLock { listeners in
            for continuation in listeners.continuations.values {
                continuation.finish()
            }
        }
    }
}
