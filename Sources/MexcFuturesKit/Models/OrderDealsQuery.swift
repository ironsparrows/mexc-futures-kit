public import Foundation

/// The filters of an order deals request.
public struct OrderDealsQuery: Sendable, Hashable {
    /// The contract symbol.
    public var symbol: String

    /// The earliest deal time to include.
    public var startTime: Date?

    /// The latest deal time to include.
    public var endTime: Date?

    /// The one-based page number.
    public var pageNumber: Int

    /// The number of deals per page, at most 100.
    public var pageSize: Int

    /// Creates the filters of an order deals request.
    public init(
        symbol: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        pageNumber: Int = 1,
        pageSize: Int = 20
    ) {
        self.symbol = symbol
        self.startTime = startTime
        self.endTime = endTime
        self.pageNumber = pageNumber
        self.pageSize = pageSize
    }
}

extension OrderDealsQuery {
    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "page_num", value: String(pageNumber)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        if let startTime {
            items.append(URLQueryItem(name: "start_time", value: String(startTime.millisecondsSince1970)))
        }
        if let endTime {
            items.append(URLQueryItem(name: "end_time", value: String(endTime.millisecondsSince1970)))
        }
        return items
    }
}
