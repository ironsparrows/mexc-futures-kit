import Synchronization
import Testing
@testable import MexcFuturesKit

@Suite("Event broadcaster")
struct EventBroadcasterTests {
    @Test func handlerCanOpenStream() async {
        let broadcaster = EventBroadcaster<Int>()
        let opened = Mutex<AsyncStream<Int>?>(nil)
        broadcaster.addHandler { _ in
            opened.withLock { $0 = $0 ?? broadcaster.makeStream(bufferingPolicy: .unbounded) }
        }

        broadcaster.yield(1)
        broadcaster.yield(2)

        let stream = opened.withLock { $0 }
        var iterator = stream?.makeAsyncIterator()
        #expect(await iterator?.next() == 2)
    }

    @Test func handlerCanEndStream() {
        let broadcaster = EventBroadcaster<Int>()
        let held = Mutex<AsyncStream<Int>?>(broadcaster.makeStream(bufferingPolicy: .unbounded))
        let calls = Mutex(0)
        broadcaster.addHandler { _ in
            held.withLock { $0 = nil }
            calls.withLock { $0 += 1 }
        }

        broadcaster.yield(1)
        broadcaster.yield(2)

        #expect(calls.withLock { $0 } == 2)
    }
}
