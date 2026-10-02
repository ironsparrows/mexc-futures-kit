import Foundation
import Synchronization

final class EventBroadcaster<Element: Sendable>: Sendable {
    private struct Listeners {
        var handlers: [@Sendable (Element) -> Void] = []
        var continuations: [(id: UUID, continuation: AsyncStream<Element>.Continuation)] = []
    }

    private let listeners = Mutex(Listeners())
    private let delivery = Mutex(())

    func addHandler(_ handler: @escaping @Sendable (Element) -> Void) {
        listeners.withLock { $0.handlers.append(handler) }
    }

    func makeStream(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy) -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.listeners.withLock { $0.continuations.removeAll { $0.id == id } }
        }
        listeners.withLock { $0.continuations.append((id, continuation)) }
        return stream
    }

    func yield(_ element: Element) {
        delivery.withLock { _ in
            let (handlers, continuations) = listeners.withLock { ($0.handlers, $0.continuations) }
            for handler in handlers {
                handler(element)
            }
            for entry in continuations {
                entry.continuation.yield(element)
            }
        }
    }

    deinit {
        listeners.withLock { listeners in
            for entry in listeners.continuations {
                entry.continuation.finish()
            }
        }
    }
}
