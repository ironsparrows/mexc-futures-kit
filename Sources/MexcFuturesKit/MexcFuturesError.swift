public import Foundation
public import SwiftyJSON

/// An error thrown by ``MexcFuturesClient`` and ``MexcFuturesWebSocket``.
public enum MexcFuturesError: Error {
    /// The server rejected the authorization token.
    case authentication(message: String)

    /// The server rejected the request signature.
    case signature(message: String)

    /// The server throttled the request.
    ///
    /// - Parameter retryAfter: The delay the server asked for, when it sent a `Retry-After` header.
    case rateLimit(message: String, retryAfter: Duration?)

    /// The server answered with an unsuccessful HTTP status.
    ///
    /// - Parameters:
    ///   - code: The MEXC error code, or the HTTP status when the body has none.
    ///   - response: The response body.
    case api(message: String, code: Int, statusCode: Int, method: String, endpoint: String, response: JSON)

    /// The request failed before the server answered.
    case network(URLError)

    /// A request parameter is invalid, so the request was not sent.
    case validation(message: String, field: String?)

    /// The WebSocket is not connected.
    case notConnected

    /// The WebSocket session is not logged in.
    case notLoggedIn

    /// The WebSocket connection could not be opened or could not send a message.
    case connectionFailed(any Error)

    /// The WebSocket server reported an error.
    case server(message: String)

    /// The WebSocket server sent a frame that is not valid JSON.
    case malformedMessage(String)

    /// An unexpected failure.
    case unknown(message: String)
}

extension MexcFuturesError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authentication(let message):
            "Authentication error: \(message)"
        case .signature:
            "Signature verification failed. This usually means your authorization token is invalid or expired. Please get a fresh WEB token from your browser."
        case .rateLimit(let message, let retryAfter):
            if let retryAfter {
                "Rate limit exceeded: \(message). Please retry after \(retryAfter.components.seconds) seconds."
            } else {
                "Rate limit exceeded: \(message)."
            }
        case .api(let message, _, let statusCode, _, _, _):
            switch statusCode {
            case 400: "Bad Request: \(message). Please check your request parameters."
            case 401: "Unauthorized: \(message). Your authorization token may be expired."
            case 403: "Forbidden: \(message). You don't have permission for this operation."
            case 404: "Not Found: \(message). The requested resource was not found."
            case 429: "Rate Limit Exceeded: \(message). Please reduce request frequency."
            case 500: "Server Error: \(message). MEXC server is experiencing issues."
            case 502, 503, 504: "Service Unavailable: \(message). MEXC service is temporarily unavailable."
            default: "API Error (\(statusCode)): \(message)"
            }
        case .network(let error):
            switch error.code {
            case .timedOut: "Request timeout. Please check your internet connection and try again."
            case .cannotFindHost, .cannotConnectToHost: "Connection failed. Please check your internet connection."
            default: "Network error: \(error.localizedDescription)"
            }
        case .validation(let message, let field):
            if let field {
                "Validation error for field '\(field)': \(message)"
            } else {
                "Validation error: \(message)"
            }
        case .notConnected:
            "WebSocket is not connected."
        case .notLoggedIn:
            "WebSocket is not logged in. Call login() first."
        case .connectionFailed(let error):
            "WebSocket connection failed: \(error.localizedDescription)"
        case .server(let message):
            "WebSocket error response: \(message)"
        case .malformedMessage(let text):
            "Malformed WebSocket message: \(text)"
        case .unknown(let message):
            message
        }
    }
}
