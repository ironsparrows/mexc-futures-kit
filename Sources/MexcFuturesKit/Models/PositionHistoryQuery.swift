import Foundation

/// The filters of a position history request.
public struct PositionHistoryQuery: Sendable, Hashable {
    /// The contract symbol, or `nil` for every contract.
    public var symbol: String?

    /// The position direction, or `nil` for both directions.
    public var type: PositionType?

    /// The one-based page number.
    public var pageNumber: Int

    /// The number of positions per page, at most 100.
    public var pageSize: Int

    /// Creates the filters of a position history request.
    public init(
        symbol: String? = nil,
        type: PositionType? = nil,
        pageNumber: Int = 1,
        pageSize: Int = 20
    ) {
        self.symbol = symbol
        self.type = type
        self.pageNumber = pageNumber
        self.pageSize = pageSize
    }
}

extension PositionHistoryQuery {
    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "page_num", value: String(pageNumber)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        if let symbol {
            items.append(URLQueryItem(name: "symbol", value: symbol))
        }
        if let type {
            items.append(URLQueryItem(name: "type", value: String(type.rawValue)))
        }
        return items
    }
}
