public import Foundation

extension MexcFuturesClient {
    /// The settings of a ``MexcFuturesClient``.
    public struct Configuration: Sendable {
        /// The WEB authorization token of a signed-in browser session.
        ///
        /// Copy the `authorization` header, which starts with `WEB`, from any request to
        /// `futures.mexc.com` in the browser's developer tools.
        public var authToken: String

        /// The base URL of the futures REST API.
        public var baseURL: URL

        /// The time limit of each request.
        public var timeout: Duration

        /// The `User-Agent` header, replacing the default desktop browser user agent.
        public var userAgent: String?

        /// Headers added to every request, replacing default headers with the same name.
        public var customHeaders: [String: String]

        /// Creates the settings of a ``MexcFuturesClient``.
        public init(
            authToken: String,
            baseURL: URL = URL(string: "https://futures.mexc.com/api/v1")!,
            timeout: Duration = .seconds(30),
            userAgent: String? = nil,
            customHeaders: [String: String] = [:]
        ) {
            self.authToken = authToken
            self.baseURL = baseURL
            self.timeout = timeout
            self.userAgent = userAgent
            self.customHeaders = customHeaders
        }
    }
}
