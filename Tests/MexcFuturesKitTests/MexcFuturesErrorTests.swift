import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("MexcFuturesError")
struct MexcFuturesErrorTests {
    @Test(arguments: [
        (400, "Bad Request: oops. Please check your request parameters."),
        (401, "Unauthorized: oops. Your authorization token may be expired."),
        (403, "Forbidden: oops. You don't have permission for this operation."),
        (404, "Not Found: oops. The requested resource was not found."),
        (429, "Rate Limit Exceeded: oops. Please reduce request frequency."),
        (500, "Server Error: oops. MEXC server is experiencing issues."),
        (503, "Service Unavailable: oops. MEXC service is temporarily unavailable."),
        (418, "API Error (418): oops"),
    ])
    func apiErrorDescribesStatus(statusCode: Int, expected: String) {
        let error = MexcFuturesError.api(
            message: "oops",
            code: statusCode,
            statusCode: statusCode,
            method: "GET",
            endpoint: "/contract/ticker",
            response: JSON(serializing: NSNull())
        )

        #expect(error.localizedDescription == expected)
    }

    @Test(arguments: [
        (URLError.Code.timedOut, "Request timeout. Please check your internet connection and try again."),
        (.cannotFindHost, "Connection failed. Please check your internet connection."),
        (.cannotConnectToHost, "Connection failed. Please check your internet connection."),
    ])
    func networkErrorDescribesCode(code: URLError.Code, expected: String) {
        #expect(MexcFuturesError.network(URLError(code)).localizedDescription == expected)
    }

    @Test func rateLimitIncludesRetryDelay() {
        let error = MexcFuturesError.rateLimit(message: "slow down", retryAfter: .seconds(30))

        #expect(error.localizedDescription == "Rate limit exceeded: slow down. Please retry after 30 seconds.")
    }

    @Test func rateLimitWithoutRetryDelay() {
        let error = MexcFuturesError.rateLimit(message: "slow down", retryAfter: nil)

        #expect(error.localizedDescription == "Rate limit exceeded: slow down.")
    }

    @Test func validationNamesField() {
        let error = MexcFuturesError.validation(message: "must be > 0", field: "vol")

        #expect(error.localizedDescription == "Validation error for field 'vol': must be > 0")
    }

    @Test func validationWithoutField() {
        let error = MexcFuturesError.validation(message: "invalid", field: nil)

        #expect(error.localizedDescription == "Validation error: invalid")
    }
}
