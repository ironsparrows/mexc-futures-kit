import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Date milliseconds")
struct DateMillisecondsTests {
    @Test func truncatesToWholeMilliseconds() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.1234)

        #expect(date.millisecondsSince1970 == 1_700_000_000_123)
    }
}
