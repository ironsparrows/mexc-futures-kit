import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Gzip decoding")
struct DataGzipTests {
    @Test(arguments: [GzipFixtures.gzippedTicker, GzipFixtures.gzippedTickerWithFileName])
    func decodesToPlainMessage(gzipped: Data) throws {
        let plain = try gzipped.gunzipped()

        #expect(String(decoding: plain, as: UTF8.self) == GzipFixtures.plainTicker)
    }

    @Test func rejectsPlainText() {
        #expect(throws: GzipError.invalidHeader) {
            try Data(GzipFixtures.plainTicker.utf8).gunzipped()
        }
    }

    @Test func rejectsTruncatedHeader() {
        var truncated = GzipFixtures.gzippedTickerWithFileName.prefix(20)
        truncated[3] = 0x08 | 0x10

        #expect(throws: GzipError.self) {
            try Data(truncated).gunzipped()
        }
    }
}
