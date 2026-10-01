public import Foundation
import yyjson

/// A JSON value from a MEXC response or WebSocket message.
///
/// The value is parsed by yyjson, a fast C parser, and fields are converted to Swift types only
/// when you read them. A missing key, an out-of-range index or a value of another type gives `nil`
/// from the optional accessors and an empty or zero value from the non-optional ones, so subscripts
/// chain safely:
///
/// ```swift
/// let price = ticker["data"]["lastPrice"].doubleValue
/// ```
public struct JSON: @unchecked Sendable {
    private let document: JSONDocument?
    private let pointer: UnsafeMutablePointer<yyjson_val>?

    static let missing = JSON(document: nil, pointer: nil)

    private init(document: JSONDocument?, pointer: UnsafeMutablePointer<yyjson_val>?) {
        self.document = document
        self.pointer = pointer
    }

    init(_ node: JSONNode) {
        self.init(document: node.document, pointer: node.pointer)
    }

    /// Creates a value by parsing JSON data.
    ///
    /// - Parameter data: The UTF-8 encoded JSON text.
    /// - Throws: `DecodingError.dataCorrupted` when `data` is not valid JSON.
    public init(data: Data) throws {
        guard let document = JSONDocument.parse(data) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The data is not valid JSON."))
        }
        self = document.decode(JSON.init)
    }

    private var node: JSONNode? {
        document.map { JSONNode(document: $0, pointer: pointer) }
    }

    /// Accesses the value of a key in an object.
    public subscript(key: String) -> JSON {
        node.map { JSON($0[key]) } ?? .missing
    }

    /// Accesses the element at an index in an array.
    public subscript(index: Int) -> JSON {
        node.map { JSON($0[index]) } ?? .missing
    }

    /// Whether the value is present and not `null`.
    public var exists: Bool {
        node?.exists ?? false
    }

    /// The value as a string, or `nil` when it is not a string.
    public var string: String? {
        node?.string
    }

    /// The value as a string, a number as its decimal text, or an empty string.
    public var stringValue: String {
        node.flatMap { $0.string ?? $0.numberText } ?? ""
    }

    /// The value as a 64-bit integer, or `nil` when it is not a number or numeric string.
    ///
    /// Integers keep full 64-bit precision. Fractions are truncated toward zero.
    public var int64: Int64? {
        node?.int64
    }

    /// The value as a 64-bit integer, or zero.
    public var int64Value: Int64 {
        int64 ?? 0
    }

    /// The value as an integer, or `nil` when it is not a number or numeric string.
    public var int: Int? {
        node?.int
    }

    /// The value as an integer, or zero.
    public var intValue: Int {
        int ?? 0
    }

    /// The value as a floating-point number, or `nil` when it is not a number or numeric string.
    public var double: Double? {
        node?.double
    }

    /// The value as a floating-point number, or zero.
    public var doubleValue: Double {
        double ?? 0
    }

    /// The value as a Boolean, or `nil` when it is not a Boolean or number.
    public var bool: Bool? {
        node?.bool
    }

    /// The value as a Boolean, or `false`.
    public var boolValue: Bool {
        bool ?? false
    }

    /// The elements of an array, or `nil` when the value is not an array.
    public var array: [JSON]? {
        node?.map(JSON.init)
    }

    /// The elements of an array, or an empty array.
    public var arrayValue: [JSON] {
        array ?? []
    }

    /// The members of an object, or `nil` when the value is not an object.
    public var dictionary: [String: JSON]? {
        node?.members().map { members in
            Dictionary(members.map { ($0.key, JSON($0.value)) }, uniquingKeysWith: { _, last in last })
        }
    }

    /// The members of an object, or an empty dictionary.
    public var dictionaryValue: [String: JSON] {
        dictionary ?? [:]
    }

    /// Returns the value encoded as compact JSON, or `null` when the value is missing.
    public func rawData() -> Data {
        node?.rawData() ?? Data("null".utf8)
    }
}

extension JSON: CustomStringConvertible {
    public var description: String {
        String(decoding: rawData(), as: UTF8.self)
    }
}

extension JSON {
    init(serializing object: Any) {
        guard JSONSerialization.isValidJSONObject([object]),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .withoutEscapingSlashes]),
              let json = try? JSON(data: data)
        else {
            self = .missing
            return
        }
        self = json
    }
}
