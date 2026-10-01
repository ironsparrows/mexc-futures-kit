import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("Request signing")
struct RequestSignatureTests {
    @Test func signsBodyWithWebToken() {
        let signature = RequestSignature(
            body: #"{"symbol":"BTC_USDT","price":50000,"vol":1,"side":1,"type":5,"openType":1}"#,
            authToken: "WEB0123456789abcdef",
            timestamp: "1700000000000"
        )

        #expect(signature.nonce == "1700000000000")
        #expect(signature.sign == "52fa6f6d1b8a5e9f75398f4912007d9b")
    }

    @Test func signsLoginWithSecretKey() {
        let signature = hmacSHA256("api-key1700000000000", secret: "secret-key")

        #expect(signature == "6e0738d6b02e3a836a19039cfc4d232bfbe77528f4eafb94399c7c0baa55973a")
    }
}
