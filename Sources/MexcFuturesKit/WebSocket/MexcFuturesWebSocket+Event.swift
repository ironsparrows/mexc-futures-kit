import Foundation

extension MexcFuturesWebSocket {
    /// An event delivered by a ``MexcFuturesWebSocket``.
    ///
    /// Market and private data events carry the `data` field of the pushed message.
    public enum Event: Sendable {
        /// The connection opened.
        case connected

        /// The connection closed.
        ///
        /// - Parameter code: The WebSocket close code, when the server sent one.
        case disconnected(code: Int?)

        /// An error occurred.
        case error(MexcFuturesError)

        /// The server answered a keep-alive ping.
        case pong(JSON)

        /// The login succeeded, carrying the full server message.
        case login(JSON)

        /// The login failed.
        case loginFailed(JSON)

        /// The private data filter was applied.
        case filterSet(JSON)

        /// The private data filter was rejected.
        case filterFailed(JSON)

        /// A subscription was confirmed.
        ///
        /// - Parameter channel: The subscribed stream, such as `ticker` or `depth.full`.
        case subscribed(channel: String, data: JSON)

        /// An unsubscription was confirmed.
        ///
        /// - Parameter channel: The unsubscribed stream, such as `ticker` or `depth.full`.
        case unsubscribed(channel: String, data: JSON)

        /// Tickers of every contract.
        case tickers(JSON)

        /// The ticker of one contract.
        case ticker(JSON)

        /// Trades of one contract.
        case deal(JSON)

        /// An order book update of one contract.
        case depth(JSON)

        /// A candle of one contract.
        case kline(JSON)

        /// The funding rate of one contract.
        case fundingRate(JSON)

        /// The index price of one contract.
        case indexPrice(JSON)

        /// The fair price of one contract.
        case fairPrice(JSON)

        /// An update of one of the user's orders.
        case orderUpdate(JSON)

        /// An execution of one of the user's orders.
        case orderDeal(JSON)

        /// An update of one of the user's positions.
        case positionUpdate(JSON)

        /// An update of one of the user's balances.
        case assetUpdate(JSON)

        /// An update of one of the user's stop orders.
        case stopOrder(JSON)

        /// An update of one of the user's stop plan orders.
        case stopPlanOrder(JSON)

        /// A liquidation risk update of one of the user's positions.
        case liquidateRisk(JSON)

        /// An auto-deleveraging level update of one of the user's positions.
        case adlLevel(JSON)

        /// A risk limit update of the user's account.
        case riskLimit(JSON)

        /// An update of one of the user's plan orders.
        case planOrder(JSON)

        /// A message on any other channel, carrying the full server message.
        case message(JSON)
    }
}

extension MexcFuturesWebSocket.Event {
    init(text: String) {
        guard let document = JSONDocument.parse(text) else {
            self = .error(.malformedMessage(text))
            return
        }
        self = document.decode { root in
            guard root.isObject else { return .error(.malformedMessage(text)) }
            return Self(channel: root["channel"].string ?? "", data: JSON(root["data"]), message: { JSON(root) })
        }
    }

    private init(channel: String, data: JSON, message: () -> JSON) {
        self = switch channel {
        case "push.depth": .depth(data)
        case "push.deal": .deal(data)
        case "push.ticker": .ticker(data)
        case "push.tickers": .tickers(data)
        case "push.kline": .kline(data)
        case "push.funding.rate": .fundingRate(data)
        case "push.index.price": .indexPrice(data)
        case "push.fair.price": .fairPrice(data)
        case "push.personal.order": .orderUpdate(data)
        case "push.personal.order.deal": .orderDeal(data)
        case "push.personal.position": .positionUpdate(data)
        case "push.personal.asset": .assetUpdate(data)
        case "push.personal.stop.order": .stopOrder(data)
        case "push.personal.stop.planorder": .stopPlanOrder(data)
        case "push.personal.liquidate.risk": .liquidateRisk(data)
        case "push.personal.adl.level": .adlLevel(data)
        case "push.personal.risk.limit": .riskLimit(data)
        case "push.personal.plan.order": .planOrder(data)
        case "pong": .pong(data)
        case "rs.login": Self.isAcknowledgement(data) ? .login(message()) : .loginFailed(data)
        case "rs.personal.filter": Self.isAcknowledgement(data) ? .filterSet(data) : .filterFailed(data)
        case "rs.error": .error(.server(message: data.string ?? data.description))
        case _ where channel.hasPrefix("rs.sub."): .subscribed(channel: String(channel.trimmingPrefix("rs.sub.")), data: data)
        case _ where channel.hasPrefix("rs.unsub."): .unsubscribed(channel: String(channel.trimmingPrefix("rs.unsub.")), data: data)
        default: .message(message())
        }
    }

    private static func isAcknowledgement(_ data: JSON) -> Bool {
        data.string == "success" || data["code"].int == 0
    }
}
