public import Foundation

extension MexcFuturesWebSocket {
    /// An event delivered by a ``MexcFuturesWebSocket``.
    ///
    /// Market and account data arrive as typed models. Acknowledgements and channels without a model
    /// carry the message's `data` field as ``JSON``.
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
        ///
        /// - Parameter serverTime: The server's clock when it answered.
        case pong(serverTime: Date)

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

        /// Summary tickers of every contract.
        case tickers([TickerSummary])

        /// The ticker of one contract.
        case ticker(Ticker)

        /// Trades of one contract.
        case deal(symbol: String, [Deal])

        /// An incremental order book update of one contract.
        case depth(symbol: String, ContractDepth)

        /// A full order book snapshot of one contract.
        case fullDepth(symbol: String, ContractDepth)

        /// A candle of one contract.
        case kline(Kline)

        /// The funding rate of one contract.
        case fundingRate(FundingRate)

        /// The index price of one contract.
        case indexPrice(ContractPrice)

        /// The fair price of one contract.
        case fairPrice(ContractPrice)

        /// An update of one of the user's orders.
        case orderUpdate(Order)

        /// An execution of one of the user's orders.
        case orderDeal(OrderDeal)

        /// An update of one of the user's positions.
        case positionUpdate(Position)

        /// An update of one of the user's balances.
        case assetUpdate(AssetUpdate)

        /// An update of one of the user's stop orders.
        case stopOrder(JSON)

        /// An update of one of the user's TP/SL orders.
        case stopPlanOrder(StopOrder)

        /// A liquidation risk update of one of the user's positions.
        case liquidateRisk(LiquidationRisk)

        /// An auto-deleveraging level update of one of the user's positions.
        case adlLevel(JSON)

        /// A risk limit update of the user's account.
        case riskLimit(JSON)

        /// An update of one of the user's trigger orders.
        case planOrder(PlanOrder)

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
            return Self(channel: root["channel"].string ?? "", root: root)
        }
    }

    private init(channel: String, root: JSONNode) {
        let data = root["data"]
        let symbol = root["symbol"].stringValue
        self = switch channel {
        case "push.depth": .depth(symbol: symbol, ContractDepth(node: data))
        case "push.depth.full": .fullDepth(symbol: symbol, ContractDepth(node: data))
        case "push.deal": .deal(symbol: symbol, data.map(Deal.init(node:)) ?? [])
        case "push.ticker": .ticker(Ticker(node: data))
        case "push.tickers": .tickers(data.map(TickerSummary.init(node:)) ?? [])
        case "push.kline": .kline(Kline(node: data))
        case "push.funding.rate": .fundingRate(FundingRate(node: data))
        case "push.index.price": .indexPrice(ContractPrice(node: data))
        case "push.fair.price": .fairPrice(ContractPrice(node: data))
        case "push.personal.order": .orderUpdate(Order(node: data))
        case "push.personal.order.deal": .orderDeal(OrderDeal(node: data))
        case "push.personal.position": .positionUpdate(Position(node: data))
        case "push.personal.asset": .assetUpdate(AssetUpdate(node: data))
        case "push.personal.stop.order": .stopOrder(JSON(data))
        case "push.personal.stop.planorder": .stopPlanOrder(StopOrder(node: data))
        case "push.personal.liquidate.risk": .liquidateRisk(LiquidationRisk(node: data))
        case "push.personal.adl.level": .adlLevel(JSON(data))
        case "push.personal.risk.limit": .riskLimit(JSON(data))
        case "push.personal.plan.order": .planOrder(PlanOrder(node: data))
        case "pong": .pong(serverTime: data.dateValue)
        case "rs.login": Self.isAcknowledgement(data) ? .login(JSON(root)) : .loginFailed(JSON(data))
        case "rs.personal.filter": Self.isAcknowledgement(data) ? .filterSet(JSON(data)) : .filterFailed(JSON(data))
        case "rs.error": .error(.server(message: data.string ?? JSON(data).description))
        case _ where channel.hasPrefix("rs.sub."): .subscribed(channel: String(channel.trimmingPrefix("rs.sub.")), data: JSON(data))
        case _ where channel.hasPrefix("rs.unsub."): .unsubscribed(channel: String(channel.trimmingPrefix("rs.unsub.")), data: JSON(data))
        default: .message(JSON(root))
        }
    }

    private static func isAcknowledgement(_ data: JSONNode) -> Bool {
        data.string == "success" || data["code"].int == 0
    }
}
