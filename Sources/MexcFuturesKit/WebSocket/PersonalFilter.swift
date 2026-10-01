import SwiftyJSON

/// A filter that selects the private data pushed after login.
public struct PersonalFilter: Sendable, Hashable {
    /// A kind of private data.
    public enum Kind: String, Sendable, CaseIterable {
        /// Order updates.
        case order = "order"

        /// Order executions.
        case orderDeal = "order.deal"

        /// Position updates.
        case position = "position"

        /// Plan order updates.
        case planOrder = "plan.order"

        /// Stop order updates.
        case stopOrder = "stop.order"

        /// Stop plan order updates.
        case stopPlanOrder = "stop.planorder"

        /// Risk limit updates.
        case riskLimit = "risk.limit"

        /// Auto-deleveraging level updates.
        case adlLevel = "adl.level"

        /// Balance updates.
        case asset = "asset"
    }

    /// The kind of private data to receive.
    public var kind: Kind

    /// The contract symbols to receive data for, or `nil` for every contract.
    public var symbols: [String]?

    /// Creates a filter for one kind of private data.
    ///
    /// - Parameters:
    ///   - kind: The kind of private data to receive.
    ///   - symbols: The contract symbols to receive data for, or `nil` for every contract.
    public init(_ kind: Kind, symbols: [String]? = nil) {
        self.kind = kind
        self.symbols = symbols
    }
}

extension PersonalFilter {
    var json: JSON {
        var json: JSON = ["filter": kind.rawValue]
        if let symbols {
            json["rules"] = JSON(symbols)
        }
        return json
    }
}
