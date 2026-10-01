# MexcFuturesKit

A Swift SDK for MEXC Futures trading, with a REST client and a WebSocket client.

> [!WARNING]
> The REST client uses browser session tokens and reverse-engineered endpoints. MEXC does not officially support futures trading through its API. Use at your own risk.

## Features

- **REST client.** Submit, cancel and query orders. Read positions, balances, fees, risk limits and market data.
- **WebSocket client.** Stream market data and private account updates as typed events over `AsyncStream`.
- **Raw JSON responses.** Every response is a [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) `JSON` value. Your code parses the fields it needs.
- **Swift concurrency.** `async`/`await` throughout, a `Sendable` client, an actor-based socket and typed throws with `MexcFuturesError`.
- **Auto-reconnect.** The socket sends keep-alive pings and reconnects after the connection drops.

## Requirements

- Swift 6.4
- macOS, iOS, tvOS, watchOS or visionOS 26

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/mexc-futures-kit.git", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "MexcFuturesKit", package: "mexc-futures-kit"),
            .product(name: "SwiftyJSON", package: "SwiftyJSON"),
        ]
    ),
]
```

MexcFuturesKit uses the `master` branch of SwiftyJSON, because only that branch makes `JSON` `Sendable`. SwiftPM does not let a version-based dependency rely on a branch. So you must also add MexcFuturesKit by branch or revision.

## Authentication

### REST: browser session token

1. Sign in to MEXC Futures in your browser.
2. Open the developer tools and go to the Network tab.
3. Select any request to `futures.mexc.com`.
4. Copy the value of the `authorization` header. It starts with `WEB`.

### WebSocket: API keys

1. Open MEXC API Management.
2. Create an API key and a secret key.
3. Enable futures trading permissions.

## REST client

```swift
import MexcFuturesKit
import SwiftyJSON

let client = MexcFuturesClient(configuration: .init(authToken: "WEB..."))

let ticker = try await client.ticker(symbol: "BTC_USDT")
print("BTC price:", ticker["data"]["lastPrice"].doubleValue)

let order = try await client.submitOrder(
    SubmitOrderRequest(
        symbol: "BTC_USDT",
        price: 50000,
        volume: 1,
        side: .openLong,
        type: .market,
        openType: .isolated,
        leverage: 10
    )
)
print("Order ID:", order["data"].int64Value)
```

A method returns the full response body, including the `success`, `code` and `data` fields. A response with `"success": false` is returned, not thrown. Check `success` before you read `data`.

| Method | Endpoint |
| --- | --- |
| `submitOrder(_:)` | `POST /private/order/submit` |
| `cancelOrders(_:)` | `POST /private/order/cancel` (up to 50 orders) |
| `cancelOrder(symbol:externalOrderID:)` | `POST /private/order/cancel_with_external` |
| `cancelAllOrders(symbol:)` | `POST /private/order/cancel_all` |
| `orderHistory(_:)` | `GET /private/order/list/history_orders` |
| `orderDeals(_:)` | `GET /private/order/list/order_deals` |
| `order(id:)` | `GET /private/order/get/{id}` |
| `order(symbol:externalOrderID:)` | `GET /private/order/external/{symbol}/{externalOid}` |
| `riskLimits()` | `GET /private/account/risk_limit` |
| `feeRates()` | `GET /private/account/contract/fee_rate` |
| `accountAsset(currency:)` | `GET /private/account/asset/{currency}` |
| `openPositions(symbol:)` | `GET /private/position/open_positions` |
| `positionHistory(_:)` | `GET /private/position/list/history_positions` |
| `ticker(symbol:)` | `GET /contract/ticker` |
| `contractDetail(symbol:)` | `GET /contract/detail` |
| `contractDepth(symbol:limit:)` | `GET /contract/depth/{symbol}` |
| `testConnection()` | Requests the `BTC_USDT` ticker and returns whether it succeeded |

### Orders

```swift
let limitOrder = SubmitOrderRequest(
    symbol: "BTC_USDT",
    price: 49000,
    volume: 1,
    side: .openLong,
    type: .limit,
    openType: .isolated,
    leverage: 10,
    stopLossPrice: 45000,
    takeProfitPrice: 55000
)

let closeOrder = SubmitOrderRequest(
    symbol: "BTC_USDT",
    price: 51000,
    volume: 1,
    side: .closeLong,
    type: .market,
    openType: .isolated,
    positionID: 12345
)
```

Before signing, the client validates the order. An invalid order throws `MexcFuturesError.validation`. The order is not sent.

## WebSocket client

```swift
let socket = MexcFuturesWebSocket(configuration: .init(apiKey: "...", secretKey: "..."))
let events = socket.events()

try await socket.connect()
try await socket.login(subscribe: false)

for await event in events {
    switch event {
    case .login:
        try await socket.setPersonalFilter([
            PersonalFilter(.order, symbols: ["BTC_USDT", "ETH_USDT"]),
            PersonalFilter(.position, symbols: ["BTC_USDT", "ETH_USDT"]),
            PersonalFilter(.asset),
        ])
    case .orderUpdate(let order):
        print("Order:", order["orderId"].int64Value, order["state"].intValue)
    case .positionUpdate(let position):
        print("Position:", position["symbol"].stringValue, position["holdVol"].doubleValue)
    case .assetUpdate(let asset):
        print("Balance:", asset["currency"].stringValue, asset["availableBalance"].doubleValue)
    case .error(let error):
        print("Error:", error.localizedDescription)
    default:
        break
    }
}
```

Each call to `events()` returns a new stream, and every stream receives every event.

### Market data

```swift
try await socket.subscribeToAllTickers()
try await socket.subscribeToTicker(symbol: "BTC_USDT")
try await socket.subscribeToDeals(symbol: "BTC_USDT")
try await socket.subscribeToDepth(symbol: "BTC_USDT")
try await socket.subscribeToFullDepth(symbol: "BTC_USDT", limit: .ten)
try await socket.subscribeToKline(symbol: "BTC_USDT", interval: .oneMinute)
try await socket.subscribeToFundingRate(symbol: "BTC_USDT")
try await socket.subscribeToIndexPrice(symbol: "BTC_USDT")
try await socket.subscribeToFairPrice(symbol: "BTC_USDT")
```

Each subscription has a matching `unsubscribeFrom…` method.

### Events

| Event | Meaning |
| --- | --- |
| `connected`, `disconnected(code:)` | The connection opened or closed |
| `login`, `loginFailed` | The result of `login(subscribe:)` |
| `filterSet`, `filterFailed` | The result of `setPersonalFilter(_:)` |
| `subscribed(channel:data:)`, `unsubscribed(channel:data:)` | The server confirmed a subscription change |
| `pong` | The server answered a keep-alive ping |
| `tickers`, `ticker`, `deal`, `depth`, `kline`, `fundingRate`, `indexPrice`, `fairPrice` | Market data |
| `orderUpdate`, `orderDeal`, `positionUpdate`, `assetUpdate`, `stopOrder`, `stopPlanOrder`, `liquidateRisk`, `adlLevel`, `riskLimit`, `planOrder` | Private account data |
| `error` | A connection, server or malformed-message error |
| `message` | A message on any other channel |

## Error handling

All methods throw `MexcFuturesError`:

```swift
do {
    let asset = try await client.accountAsset(currency: "USDT")
    print(asset["data"]["availableBalance"].doubleValue)
} catch .authentication {
    print("Update your WEB token.")
} catch .signature {
    print("The WEB token is invalid or expired.")
} catch .rateLimit(_, let retryAfter) {
    print("Retry after", retryAfter ?? .seconds(1))
} catch {
    print(error.localizedDescription)
}
```

## Logging

The clients log through [swift-log](https://github.com/apple/swift-log). Pass your own `Logger` to change the level or the destination:

```swift
var logger = Logger(label: "trading")
logger.logLevel = .debug
let client = MexcFuturesClient(configuration: .init(authToken: "WEB..."), logger: logger)
```

The logs never include request signatures or WebSocket login parameters.

## Testing

```bash
swift test
```

The default test run stays offline. To also run the live checks against public MEXC endpoints:

```bash
MEXC_LIVE_TESTS=1 swift test
```
