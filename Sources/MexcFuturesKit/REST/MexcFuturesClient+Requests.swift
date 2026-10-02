import Foundation
import Logging

extension MexcFuturesClient {
    func get(
        _ endpoint: Endpoint,
        authToken: String? = nil,
        pathComponents: [String] = [],
        query: [URLQueryItem] = []
    ) async throws(MexcFuturesError) -> JSONDocument {
        let request = makeRequest(method: "GET", endpoint: endpoint, authToken: authToken, pathComponents: pathComponents, query: query)
        return try await send(request)
    }

    func post(_ endpoint: Endpoint, authToken: String, body: some Encodable) async throws(MexcFuturesError) -> JSONDocument {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw .validation(message: "Request body could not be encoded: \(error.localizedDescription)", field: nil)
        }
        let signature = RequestSignature(
            body: String(decoding: data, as: UTF8.self),
            authToken: authToken,
            timestamp: String(Date.now.millisecondsSince1970)
        )
        var request = makeRequest(method: "POST", endpoint: endpoint, authToken: authToken)
        request.setValue(signature.nonce, forHTTPHeaderField: "x-mxc-nonce")
        request.setValue(signature.sign, forHTTPHeaderField: "x-mxc-sign")
        request.httpBody = data
        logger.debug("Request body", metadata: ["body": "\(String(decoding: data, as: UTF8.self))"])
        return try await send(request)
    }

    private func makeRequest(
        method: String,
        endpoint: Endpoint,
        authToken: String?,
        pathComponents: [String] = [],
        query: [URLQueryItem] = []
    ) -> URLRequest {
        var url = configuration.baseURL.appending(path: endpoint.rawValue)
        for component in pathComponents {
            url.append(component: component)
        }
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout / .seconds(1))
        request.httpMethod = method
        var headers = Self.defaultHeaders
        if let userAgent = configuration.userAgent {
            headers["user-agent"] = userAgent
        }
        for (name, value) in configuration.customHeaders {
            headers[name.lowercased()] = value
        }
        if let authToken {
            headers["authorization"] = authToken
        }
        request.allHTTPHeaderFields = headers
        return request
    }

    private func send(_ request: URLRequest) async throws(MexcFuturesError) -> JSONDocument {
        let method = request.httpMethod ?? "GET"
        let endpoint = request.url.map { String($0.path().trimmingPrefix(configuration.baseURL.path())) } ?? ""
        logger.debug("Sending request", metadata: ["method": "\(method)", "url": "\(request.url?.absoluteString ?? "")"])

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.response(for: request)
        } catch let error as URLError {
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw .network(error)
        } catch {
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw .unknown(message: error.localizedDescription)
        }

        logger.debug("Received response", metadata: ["status": "\(response.statusCode)"])
        guard (200..<300).contains(response.statusCode) else {
            let error = MexcFuturesError(response: response, body: (try? JSON(data: data)) ?? .missing, method: method, endpoint: endpoint)
            logger.debug("Request failed", metadata: ["error": "\(error.localizedDescription)"])
            throw error
        }
        guard let document = JSONDocument.parse(data) else {
            throw .malformedMessage(String(decoding: data, as: UTF8.self))
        }
        return document
    }
}

extension MexcFuturesError {
    init(response: HTTPURLResponse, body: JSON, method: String, endpoint: String) {
        let statusCode = response.statusCode
        let message = body["message"].stringValue.isEmpty ? "Request failed with status code \(statusCode)" : body["message"].stringValue
        let code = body["code"].intValue == 0 ? statusCode : body["code"].intValue

        switch statusCode {
        case 401:
            self = .authentication(message: message)
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init).map(Duration.seconds)
            self = .rateLimit(message: message, retryAfter: retryAfter)
        case _ where code == 602 || message.contains("signature") || message.contains("Signature"):
            self = .signature(message: message)
        default:
            self = .api(message: message, code: code, statusCode: statusCode, method: method, endpoint: endpoint, response: body)
        }
    }
}
