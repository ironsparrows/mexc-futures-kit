import Foundation
import Logging
import Synchronization
@testable import MexcFuturesKit

final class StubTransport: HTTPTransport {
    private let result: @Sendable () throws -> (Data, Int, [String: String])
    private let recorded = Mutex<[URLRequest]>([])

    init(statusCode: Int = 200, body: String = #"{"success":true,"code":0}"#, headers: [String: String] = [:]) {
        result = { (Data(body.utf8), statusCode, headers) }
    }

    init(error: any Error) {
        result = { throw error }
    }

    var requests: [URLRequest] {
        recorded.withLock { $0 }
    }

    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recorded.withLock { $0.append(request) }
        let (data, statusCode, headers) = try result()
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (data, response)
    }
}

extension MexcFuturesClient {
    static func stubbed(_ transport: StubTransport, userAgent: String? = nil, customHeaders: [String: String] = [:]) -> Self {
        MexcFuturesClient(
            configuration: Configuration(authToken: "WEB-token", userAgent: userAgent, customHeaders: customHeaders),
            transport: transport,
            logger: .init(label: "test")
        )
    }
}
