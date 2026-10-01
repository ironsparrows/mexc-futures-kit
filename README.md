# MexcFuturesKit

A Swift SDK for MEXC Futures trading, with a REST client and a WebSocket client.

> [!WARNING]
> The REST client uses browser session tokens and reverse-engineered endpoints. MEXC does not officially support futures trading through its API. Use at your own risk.

## Features

- **REST client.** Submit, cancel and query orders. Read positions, balances, fees, risk limits and market data.
- **WebSocket client.** Stream market data and private account updates as typed events over `AsyncStream`.
- **Typed REST results.** Every REST method returns a `Result` with typed models, such as `Ticker`, `Order` and `Position`, or MEXC's rejection. WebSocket pushes decode into the same typed models.
- **Fast.** Decodes MEXC responses and WebSocket messages 10–26× faster than Foundation. See [Performance](#performance).
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
        ]
    ),
]
```

## Authentication

Market data needs no credentials, on REST or on the WebSocket. Account data and trading need the WEB token of a signed-in browser session. The same token works for REST and the WebSocket.

### REST: browser session token

`MexcFuturesClient.account(authToken:)` needs this token.

1. Sign in to MEXC Futures in your browser.
2. Open the developer tools and go to the Network tab.
3. Select any request to `futures.mexc.com`.
4. Copy the value of the `authorization` header. It starts with `WEB`.

### WebSocket: WEB token or API keys

`MexcFuturesWebSocket.login(authToken:subscribe:)` takes the same WEB token as REST.

`MexcFuturesWebSocket.login(apiKey:secretKey:subscribe:)` takes an API key instead. This is the login MEXC documents:

1. Open MEXC API Management.
2. Create an API key and a secret key.
3. Enable futures trading permissions.

## REST client

`MexcFuturesClient` serves public market data without credentials. `account(authToken:)` returns a `MexcFuturesClient.Account`, which serves account data and trading. Every account request carries the WEB token.

```swift
import MexcFuturesKit

let client = MexcFuturesClient()
let ticker = try await client.ticker(symbol: "BTC_USDT").get()
print("BTC price:", ticker.lastPrice)

let account = client.account(authToken: "WEB...")
let order = try await account.submitOrder(
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
switch order {
case .success(let orderID):
    print("Order ID:", orderID)
case .failure(let error):
    print(error.localizedDescription)
}
```

Every method returns a `Result`:

- `.success` carries the typed data.
- `.failure(.rejected(code:message:))` carries MEXC's error code and message when it answers `"success": false`.
- Network, HTTP and signature failures are thrown, like every other `MexcFuturesError`.

Call `get()` to turn a rejection into a thrown error, or switch on the result to handle it in place:

```swift
switch try await account.openPositions() {
case .success(let positions):
    for position in positions {
        print(position.symbol, position.holdVolume, position.liquidatePrice)
    }
case .failure(.rejected(let code, let message)):
    print("MEXC rejected the request:", code, message)
case .failure(let error):
    print(error.localizedDescription)
}
```

### Market data: `MexcFuturesClient`

| Method | Success value | Endpoint |
| --- | --- | --- |
| `ticker(symbol:)` | `Ticker` | `GET /contract/ticker` |
| `contractDetail(symbol:)` | `[ContractDetail]` | `GET /contract/detail` |
| `contractDepth(symbol:limit:)` | `ContractDepth` | `GET /contract/depth/{symbol}` |
| `testConnection()` | `Bool` | Requests the `BTC_USDT` ticker and returns whether it succeeded |

### Account data and trading: `MexcFuturesClient.Account`

| Method | Success value | Endpoint |
| --- | --- | --- |
| `submitOrder(_:)` | `Int64`, the order ID | `POST /private/order/submit` |
| `cancelOrders(_:)` | `[CancelOrderResult]` | `POST /private/order/cancel` (up to 50 orders) |
| `cancelOrder(symbol:externalOrderID:)` | `ExternalOrderReference` | `POST /private/order/cancel_with_external` |
| `cancelAllOrders(symbol:)` | `Void` | `POST /private/order/cancel_all` |
| `orderHistory(_:)` | `[Order]` | `GET /private/order/list/history_orders` |
| `orderDeals(_:)` | `[OrderDeal]` | `GET /private/order/list/order_deals` |
| `order(id:)` | `Order` | `GET /private/order/get/{id}` |
| `order(symbol:externalOrderID:)` | `Order` | `GET /private/order/external/{symbol}/{externalOid}` |
| `riskLimits()` | `[RiskLimit]` | `GET /private/account/risk_limit` |
| `feeRates()` | `[FeeRate]` | `GET /private/account/contract/fee_rate` |
| `accountAsset(currency:)` | `AccountAsset` | `GET /private/account/asset/{currency}` |
| `openPositions(symbol:)` | `[Position]` | `GET /private/position/open_positions` |
| `positionHistory(_:)` | `[Position]` | `GET /private/position/list/history_positions` |

Code fields such as `side`, `state` and `orderType` are enums. They are `nil` when MEXC sends a value this SDK does not know yet.

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

Before signing, the account client validates the order. An invalid order throws `MexcFuturesError.validation`. The order is not sent.

## WebSocket client

Market data needs no credentials:

```swift
let socket = MexcFuturesWebSocket()
let events = socket.events()

try await socket.connect()
try await socket.subscribeToTicker(symbol: "BTC_USDT")

for await event in events {
    if case .ticker(let ticker) = event {
        print("BTC price:", ticker.lastPrice)
    }
}
```

Private account data needs a login. `login(authToken:subscribe:)` waits for the server to accept the WEB token. It returns a `MexcFuturesWebSocket.Account`, which selects the private data the server pushes:

```swift
let account = try await socket.login(authToken: "WEB...", subscribe: false)
try await account.setPersonalFilter([
    PersonalFilter(.order, symbols: ["BTC_USDT", "ETH_USDT"]),
    PersonalFilter(.position, symbols: ["BTC_USDT", "ETH_USDT"]),
    PersonalFilter(.asset),
])

for await event in events {
    switch event {
    case .orderUpdate(let order):
        print("Order:", order.orderID, order.state as Any)
    case .positionUpdate(let position):
        print("Position:", position.symbol, position.holdVolume)
    case .assetUpdate(let asset):
        print("Balance:", asset.currency, asset.availableBalance)
    case .error(let error):
        print("Error:", error.localizedDescription)
    default:
        break
    }
}
```

A rejected login throws `MexcFuturesError.authentication`. Account methods throw `MexcFuturesError.notLoggedIn` once the session is no longer logged in.

Each call to `events()` returns a new stream, and every stream receives every event.

### Lowest latency: `onEvent`

`onEvent(_:)` calls a handler on the network thread as each message arrives. Nothing is handed off to another task, so this is the fastest way to consume the socket. Calls never overlap. Keep the handler short, because the socket handles no further messages until it returns.

```swift
socket.onEvent { event in
    if case .depth(_, let depth) = event {
        print("Best ask:", depth.asks.first?.price as Any)
    }
}
```

### Reconnecting

With `autoReconnect` on (the default), the socket reconnects after the connection drops. Then it restores the session: it logs in again with the same keys, re-applies the last personal filter and re-subscribes to every active market stream. After that it delivers `connected`. `disconnect()` closes the connection and forgets the login and the subscriptions.

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

### Compression

Compression is off by default. MEXC pushes small, frequent messages, so decompressing each one costs more latency than it saves bandwidth.

| Kind | Control | Default |
| --- | --- | --- |
| Transport (permessage-deflate, RFC 7692) | Not available. WebSocketKit and SwiftNIO do not implement it, so the handshake never offers it. | Off |
| Payload gzip | `subscribeToAllTickers(gzip:)` | Off |
| Order book merging | `subscribeToDepth(symbol:compress:)`. MEXC's `compress` field merges changes and pushes them about every 200 ms. It does not compress bytes. | Every change |

When you receive every depth change, keep your own order book. Start from a `contractDepth(symbol:limit:)` snapshot, apply the changes in `version` order, and reload the snapshot when a version is missing.

### Events

| Event | Payload | Meaning |
| --- | --- | --- |
| `connected`, `disconnected(code:)` | | The connection opened or closed |
| `login`, `loginFailed` | `JSON` | The result of a login |
| `filterSet`, `filterFailed` | `JSON` | The result of `setPersonalFilter(_:)` |
| `subscribed(channel:data:)`, `unsubscribed(channel:data:)` | `JSON` | The server confirmed a subscription change |
| `pong(serverTime:)` | `Date` | The server answered a keep-alive ping |
| `tickers` | `[TickerSummary]` | Every contract's ticker |
| `ticker` | `Ticker` | One contract's ticker |
| `deal(symbol:_:)` | `[Deal]` | Trades |
| `depth(symbol:_:)`, `fullDepth(symbol:_:)` | `ContractDepth` | Order book changes and snapshots |
| `kline` | `Kline` | A candlestick |
| `fundingRate` | `FundingRate` | The funding rate |
| `indexPrice`, `fairPrice` | `ContractPrice` | The index or fair price |
| `orderUpdate` | `Order` | An order changed |
| `orderDeal` | `OrderDeal` | An order filled |
| `positionUpdate` | `Position` | A position changed |
| `assetUpdate` | `AssetUpdate` | A balance changed |
| `stopPlanOrder` | `StopOrder` | A take-profit or stop-loss order changed |
| `planOrder` | `PlanOrder` | A trigger order changed |
| `liquidateRisk` | `LiquidationRisk` | A position's liquidation price or margin ratio changed |
| `stopOrder`, `adlLevel`, `riskLimit` | `JSON` | Other private account data |
| `error` | `MexcFuturesError` | A connection, server or malformed-message error |
| `message` | `JSON` | A message on any other channel |

## JSON

Acknowledgements, unmodeled channels and API error bodies carry a `JSON` value. It is parsed by [yyjson](https://github.com/ibireme/yyjson), and fields are converted to Swift types only when you read them:

```swift
let symbol = message["symbol"].stringValue
let orderID = message["data"]["orderId"].int64Value
let levels = message["data"]["bids"].arrayValue
```

Optional accessors (`string`, `int64`, `double`, `bool`, `array`, `dictionary`) return `nil` for a missing value or a value of another type. Non-optional accessors (`stringValue`, `int64Value`, …) return an empty or zero value. Integers keep full 64-bit precision, so order IDs such as `817027833053397504` stay exact. `rawData()` returns the value as compact JSON, ready for `JSONDecoder` if you prefer your own `Codable` models.

## Performance

### Why yyjson

MexcFuturesKit parses JSON with [yyjson](https://github.com/ibireme/yyjson), a JSON library written in C, instead of Foundation.

- **`JSONDecoder` does more work per field.** Every field goes through a `Codable` container and a key lookup before its value reaches your struct.
- **yyjson builds no intermediate objects.** It parses into one block of C memory. The SDK reads each field straight from that block into the model, then frees the block as soon as the model is built.
- **Fields are read in the order MEXC sends them,** so finding the next field takes one step instead of a search through the whole object.

### REST decoding

Measured on one Mac with release builds and real MEXC payloads: a ticker (588 bytes), an order book with 20 levels per side (772 bytes), and every contract (1,207 contracts, 2.3 MB). The numbers are the median of 3 runs. The `Codable` structs given to `JSONDecoder` have the same fields as the SDK models.

| | Foundation `JSONDecoder` | **MexcFuturesKit** |
| --- | --- | --- |
| `Ticker` | 6.26 µs | **0.45 µs** (14× faster) |
| `ContractDepth`, 20 levels per side | 27.5 µs | **1.07 µs** (26× faster) |
| `[ContractDetail]`, 1,207 contracts | 14.5 ms | **1.37 ms** (10× faster) |

### WebSocket

Decoding one real MEXC depth update into `ContractDepth`, which is the most frequent message on a market data connection (median of 3 runs):

| | Foundation `JSONDecoder` | **MexcFuturesKit** |
| --- | --- | --- |
| One depth update | 2.99 µs | **0.29 µs** (10× faster) |

The whole client was also measured end to end. A local server replayed captured MEXC depth traffic to it on one Mac, in a release build. Latency runs from the server's send to your handler.

| | `onEvent` | `events()` stream |
| --- | --- | --- |
| Latency at 3,440 msg/s (live MEXC rate), p50 / p99 | 0.06 / 0.17 ms | 0.09 / 0.23 ms |
| CPU at 3,440 msg/s | 3% of one core | 6% of one core |
| CPU per message at full load | 1.9 µs | 3.5 µs |
| Peak memory | 14 MB | 14 MB |

### Why speed matters

- **Reaction time.** Decoding happens before your code sees a price. Every microsecond spent decoding is added to the time it takes to react to the market.
- **Bursts.** Ten liquid contracts pushed about 3,440 depth updates per second in normal trading, and volatile markets push several times more. Decoding cost decides whether a client keeps up or falls behind and queues stale prices.
- **More markets per machine.** Less CPU per message leaves room for more symbols, more connections and the strategy itself.
- **Apps.** Decoding the contract list with `JSONDecoder` takes 14.5 ms, nearly a whole 60 Hz frame (16.7 ms). MexcFuturesKit takes 1.4 ms. On iPhone, less CPU also means less battery and heat.
- **Memory.** The parsed JSON is freed right after decoding, so a running socket stays around 14 MB.

## Error handling

All methods throw `MexcFuturesError`:

```swift
do {
    let asset = try await account.accountAsset(currency: "USDT").get()
    print(asset.availableBalance)
} catch .rejected(let code, let message) {
    print("MEXC rejected the request:", code, message)
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
let client = MexcFuturesClient(logger: logger)
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
