import Foundation

enum GzipFixtures {
    static let plainTicker = #"{"channel":"push.ticker","data":{"symbol":"BTC_USDT","lastPrice":83500.5},"symbol":"BTC_USDT","ts":1790860413855}"#

    static let gzippedTicker = Data(base64Encoded: "H4sIAAAAAAAC/6tWSs5IzMtLzVGyUiooLc7QK8lMzk4tUtJRSkksSVSyqlYqrsxNygdJO4U4x4cGu4QA5XISi0sCijKTU5WsLIxNDQz0TGt1sCosKVayMjS3NLAwMzAxNLYwNa0FAJVZG8pxAAAA")!

    static let gzippedTickerWithFileName = Data(base64Encoded: "H4sICAAAAAAC/3RpY2tlci5qc29uAKtWSs5IzMtLzVGyUiooLc7QK8lMzk4tUtJRSkksSVSyqlYqrsxNygdJO4U4x4cGu4QA5XISi0sCijKTU5WsLIxNDQz0TGt1sCosKVayMjS3NLAwMzAxNLYwNa0FAJVZG8pxAAAA")!
}
