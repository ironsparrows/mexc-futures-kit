import Foundation

/// The filters of an order history request.
public struct OrderHistoryQuery: Sendable, Hashable {
    /// The contract symbol, or `nil` for every contract.
    public var symbol: String?

    /// The order origin, or `nil` for every origin.
    public var category: OrderCategory?

    /// The order states to include, or an empty array for every state.
    public var states: [OrderState]

    /// The one-based page number.
    public var pageNumber: Int

    /// The number of orders per page, at most 100.
    public var pageSize: Int

    /// Creates the filters of an order history request.
    public init(
        symbol: String? = nil,
        category: OrderCategory? = nil,
        states: [OrderState] = [],
        pageNumber: Int = 1,
        pageSize: Int = 20
    ) {
        self.symbol = symbol
        self.category = category
        self.states = states
        self.pageNumber = pageNumber
        self.pageSize = pageSize
    }
}

extension OrderHistoryQuery {
    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "page_num", value: String(pageNumber)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        if let symbol {
            items.append(URLQueryItem(name: "symbol", value: symbol))
        }
        if let category {
            items.append(URLQueryItem(name: "category", value: String(category.rawValue)))
        }
        if !states.isEmpty {
            items.append(URLQueryItem(name: "states", value: states.map { String($0.rawValue) }.joined(separator: ",")))
        }
        return items
    }
}
