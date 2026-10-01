public import Foundation

/// A JSON value from a MEXC response or WebSocket message.
///
/// The value keeps the original JSON text and decodes only what you read. A missing key,
/// an out-of-range index or a value of another type gives `nil` from the optional accessors
/// and an empty or zero value from the non-optional ones, so subscripts chain safely:
///
/// ```swift
/// let price = ticker["data"]["lastPrice"].doubleValue
/// ```
public struct JSON: Sendable {
    private let text: Data
    private let range: Range<Int>?

    init(text: Data, range: Range<Int>?) {
        self.text = text
        self.range = range
    }

    /// Creates a value by validating JSON data.
    ///
    /// - Parameter data: The UTF-8 encoded JSON text.
    /// - Throws: `DecodingError.dataCorrupted` when `data` is not valid JSON.
    public init(data: Data) throws {
        let range = data.withUnsafeBytes { JSONScanner(bytes: $0).documentRange() }
        guard let range else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The data is not valid JSON."))
        }
        self.init(text: data, range: range)
    }

    /// Accesses the value of a key in an object.
    public subscript(key: String) -> JSON {
        JSON(text: text, range: scan { $0.member(key, in: $1) })
    }

    /// Accesses the element at an index in an array.
    public subscript(index: Int) -> JSON {
        JSON(text: text, range: scan { $0.elements(in: $1).flatMap { $0.indices.contains(index) ? $0[index] : nil } })
    }

    /// Whether the value is present and not `null`.
    public var exists: Bool {
        scan { $0.kind(at: $1.lowerBound) == .null ? nil : true } ?? false
    }

    /// The value as a string, or `nil` when it is not a string.
    public var string: String? {
        scan { $0.string(in: $1) }
    }

    /// The value as a string, a number as its JSON text, or an empty string.
    public var stringValue: String {
        scan { $0.string(in: $1) ?? ($0.kind(at: $1.lowerBound) == .number ? $0.text(in: $1) : nil) } ?? ""
    }

    /// The value as a 64-bit integer, or `nil` when it is not a number or numeric string.
    ///
    /// Integers keep full 64-bit precision. Fractions are truncated toward zero.
    public var int64: Int64? {
        scan { scanner, range in
            switch scanner.kind(at: range.lowerBound) {
            case .number: scanner.int64(in: range)
            case .string: scanner.string(in: range).flatMap(Int64.init)
            default: nil
            }
        }
    }

    /// The value as a 64-bit integer, or zero.
    public var int64Value: Int64 {
        int64 ?? 0
    }

    /// The value as an integer, or `nil` when it is not a number or numeric string.
    public var int: Int? {
        int64.map(Int.init(truncatingIfNeeded:))
    }

    /// The value as an integer, or zero.
    public var intValue: Int {
        int ?? 0
    }

    /// The value as a floating-point number, or `nil` when it is not a number or numeric string.
    public var double: Double? {
        scan { scanner, range in
            switch scanner.kind(at: range.lowerBound) {
            case .number: scanner.double(in: range)
            case .string: scanner.string(in: range).flatMap(Double.init)
            default: nil
            }
        }
    }

    /// The value as a floating-point number, or zero.
    public var doubleValue: Double {
        double ?? 0
    }

    /// The value as a Boolean, or `nil` when it is not a Boolean or number.
    public var bool: Bool? {
        scan { scanner, range in
            switch scanner.kind(at: range.lowerBound) {
            case .true: true
            case .false: false
            case .number: scanner.double(in: range).map { $0 != 0 }
            default: nil
            }
        }
    }

    /// The value as a Boolean, or `false`.
    public var boolValue: Bool {
        bool ?? false
    }

    /// The elements of an array, or `nil` when the value is not an array.
    public var array: [JSON]? {
        scan { $0.elements(in: $1) }?.map { JSON(text: text, range: $0) }
    }

    /// The elements of an array, or an empty array.
    public var arrayValue: [JSON] {
        array ?? []
    }

    /// The members of an object, or `nil` when the value is not an object.
    public var dictionary: [String: JSON]? {
        scan { $0.members(in: $1) }.map { members in
            Dictionary(members.map { ($0.key, JSON(text: text, range: $0.value)) }, uniquingKeysWith: { _, last in last })
        }
    }

    /// The members of an object, or an empty dictionary.
    public var dictionaryValue: [String: JSON] {
        dictionary ?? [:]
    }

    /// Returns the value's JSON text, or `null` when the value is missing.
    public func rawData() -> Data {
        guard let range else { return Data("null".utf8) }
        return text.withUnsafeBytes { Data($0[range]) }
    }

    private func scan<Value>(_ body: (JSONScanner, Range<Int>) -> Value?) -> Value? {
        guard let range else { return nil }
        return text.withUnsafeBytes { body(JSONScanner(bytes: $0), range) }
    }
}

extension JSON: CustomStringConvertible {
    public var description: String {
        String(decoding: rawData(), as: UTF8.self)
    }
}

extension JSON {
    init(serializing object: Any) {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data("null".utf8)
        self.init(text: data, range: 0..<data.count)
    }

    static func message(_ data: Data) -> (channel: String, data: JSON, message: JSON)? {
        let fields = data.withUnsafeBytes { bytes -> (channel: String, data: Range<Int>?, end: Int)? in
            let scanner = JSONScanner(bytes: bytes)
            guard let (members, end) = scanner.topLevelMembers(["channel", "data"]) else { return nil }
            return (members[0].flatMap { scanner.string(in: $0) } ?? "", members[1], end)
        }
        guard let fields else { return nil }
        let message = JSON(text: data, range: 0..<fields.end)
        return (fields.channel, JSON(text: data, range: fields.data), message)
    }
}

private struct JSONScanner {
    enum Kind {
        case object, array, string, number, `true`, `false`, null
    }

    let bytes: UnsafeRawBufferPointer

    func documentRange() -> Range<Int>? {
        let start = skipWhitespace(0)
        guard let end = valueEnd(start, depth: 0), skipWhitespace(end) == bytes.count else { return nil }
        return start..<end
    }

    func topLevelMembers(_ keys: [String]) -> (members: [Range<Int>?], end: Int)? {
        let start = skipWhitespace(0)
        guard byte(start) == UInt8(ascii: "{") else { return nil }
        var found = [Range<Int>?](repeating: nil, count: keys.count)
        let end = forEachMember(from: start, depth: 0) { keyRange, valueRange in
            for (index, key) in keys.enumerated() where found[index] == nil && keyEquals(key, keyRange) {
                found[index] = valueRange
            }
            return true
        }
        guard let end, skipWhitespace(end) == bytes.count else { return nil }
        return (found, end)
    }

    func kind(at index: Int) -> Kind? {
        guard let byte = byte(index) else { return nil }
        return switch byte {
        case UInt8(ascii: "{"): .object
        case UInt8(ascii: "["): .array
        case UInt8(ascii: "\""): .string
        case UInt8(ascii: "t"): .true
        case UInt8(ascii: "f"): .false
        case UInt8(ascii: "n"): .null
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): .number
        default: nil
        }
    }

    func member(_ key: String, in range: Range<Int>) -> Range<Int>? {
        guard kind(at: range.lowerBound) == .object else { return nil }
        var result: Range<Int>?
        _ = forEachMember(from: range.lowerBound, depth: 0) { keyRange, valueRange in
            guard keyEquals(key, keyRange) else { return true }
            result = valueRange
            return false
        }
        return result
    }

    func members(in range: Range<Int>) -> [(key: String, value: Range<Int>)]? {
        guard kind(at: range.lowerBound) == .object else { return nil }
        var members: [(key: String, value: Range<Int>)] = []
        _ = forEachMember(from: range.lowerBound, depth: 0) { keyRange, valueRange in
            members.append((string(in: keyRange) ?? "", valueRange))
            return true
        }
        return members
    }

    func elements(in range: Range<Int>) -> [Range<Int>]? {
        guard kind(at: range.lowerBound) == .array else { return nil }
        var elements: [Range<Int>] = []
        var index = skipWhitespace(range.lowerBound + 1)
        if byte(index) == UInt8(ascii: "]") { return elements }
        while let end = valueEnd(index, depth: 1) {
            elements.append(index..<end)
            index = skipWhitespace(end)
            guard byte(index) == UInt8(ascii: ",") else { break }
            index = skipWhitespace(index + 1)
        }
        return elements
    }

    func text(in range: Range<Int>) -> String {
        String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range]), as: UTF8.self)
    }

    func string(in range: Range<Int>) -> String? {
        guard kind(at: range.lowerBound) == .string else { return nil }
        let content = (range.lowerBound + 1)..<(range.upperBound - 1)
        let raw = UnsafeRawBufferPointer(rebasing: bytes[content])
        guard raw.contains(UInt8(ascii: "\\")) else { return String(decoding: raw, as: UTF8.self) }
        return unescape(raw)
    }

    func int64(in range: Range<Int>) -> Int64? {
        var index = range.lowerBound
        let negative = byte(index) == UInt8(ascii: "-")
        if negative { index += 1 }
        var value: Int64 = 0
        while index < range.upperBound, let digit = byte(index), digit >= UInt8(ascii: "0"), digit <= UInt8(ascii: "9") {
            let (multiplied, overflow) = value.multipliedReportingOverflow(by: 10)
            let (added, addOverflow) = multiplied.addingReportingOverflow(Int64(digit - UInt8(ascii: "0")))
            guard !overflow, !addOverflow else { return double(in: range).flatMap { Int64(exactly: $0.rounded(.towardZero)) } }
            value = added
            index += 1
        }
        if index < range.upperBound {
            return double(in: range).flatMap { Int64(exactly: $0.rounded(.towardZero)) }
        }
        return negative ? -value : value
    }

    func double(in range: Range<Int>) -> Double? {
        Double(text(in: range))
    }

    private func byte(_ index: Int) -> UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private func skipWhitespace(_ index: Int) -> Int {
        var index = index
        while let byte = byte(index), byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
            index += 1
        }
        return index
    }

    private func valueEnd(_ index: Int, depth: Int) -> Int? {
        guard depth < 512, let kind = kind(at: index) else { return nil }
        switch kind {
        case .object:
            return forEachMember(from: index, depth: depth) { _, _ in true }
        case .array:
            var index = skipWhitespace(index + 1)
            if byte(index) == UInt8(ascii: "]") { return index + 1 }
            while true {
                guard let end = valueEnd(index, depth: depth + 1) else { return nil }
                index = skipWhitespace(end)
                switch byte(index) {
                case UInt8(ascii: ","): index = skipWhitespace(index + 1)
                case UInt8(ascii: "]"): return index + 1
                default: return nil
                }
            }
        case .string:
            return stringEnd(index)
        case .number:
            var end = index + 1
            while let byte = byte(end), (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")) || byte == UInt8(ascii: ".")
                || byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") {
                end += 1
            }
            return end
        case .true:
            return literalEnd(index, "true")
        case .false:
            return literalEnd(index, "false")
        case .null:
            return literalEnd(index, "null")
        }
    }

    private func forEachMember(from index: Int, depth: Int, _ body: (Range<Int>, Range<Int>) -> Bool) -> Int? {
        var index = skipWhitespace(index + 1)
        if byte(index) == UInt8(ascii: "}") { return index + 1 }
        while true {
            guard byte(index) == UInt8(ascii: "\""), let keyEnd = stringEnd(index) else { return nil }
            let keyRange = index..<keyEnd
            index = skipWhitespace(keyEnd)
            guard byte(index) == UInt8(ascii: ":") else { return nil }
            index = skipWhitespace(index + 1)
            guard let valueEnd = valueEnd(index, depth: depth + 1) else { return nil }
            guard body(keyRange, index..<valueEnd) else { return valueEnd }
            index = skipWhitespace(valueEnd)
            switch byte(index) {
            case UInt8(ascii: ","): index = skipWhitespace(index + 1)
            case UInt8(ascii: "}"): return index + 1
            default: return nil
            }
        }
    }

    private func stringEnd(_ index: Int) -> Int? {
        var index = index + 1
        while let byte = byte(index) {
            switch byte {
            case UInt8(ascii: "\""): return index + 1
            case UInt8(ascii: "\\"): index += 2
            case 0..<0x20: return nil
            default: index += 1
            }
        }
        return nil
    }

    private func literalEnd(_ index: Int, _ literal: StaticString) -> Int? {
        let end = index + literal.utf8CodeUnitCount
        guard end <= bytes.count,
              UnsafeRawBufferPointer(rebasing: bytes[index..<end]).elementsEqual(UnsafeRawBufferPointer(start: literal.utf8Start, count: literal.utf8CodeUnitCount))
        else { return nil }
        return end
    }

    private func keyEquals(_ key: String, _ keyRange: Range<Int>) -> Bool {
        let raw = UnsafeRawBufferPointer(rebasing: bytes[(keyRange.lowerBound + 1)..<(keyRange.upperBound - 1)])
        if raw.contains(UInt8(ascii: "\\")) {
            return unescape(raw) == key
        }
        return raw.elementsEqual(key.utf8)
    }

    private func unescape(_ raw: UnsafeRawBufferPointer) -> String? {
        var result: [UInt8] = []
        result.reserveCapacity(raw.count)
        var index = 0
        while index < raw.count {
            let byte = raw[index]
            guard byte == UInt8(ascii: "\\") else {
                result.append(byte)
                index += 1
                continue
            }
            guard index + 1 < raw.count else { return nil }
            let escaped = raw[index + 1]
            index += 2
            switch escaped {
            case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): result.append(escaped)
            case UInt8(ascii: "b"): result.append(0x08)
            case UInt8(ascii: "f"): result.append(0x0C)
            case UInt8(ascii: "n"): result.append(0x0A)
            case UInt8(ascii: "r"): result.append(0x0D)
            case UInt8(ascii: "t"): result.append(0x09)
            case UInt8(ascii: "u"):
                guard var scalar = hexValue(raw, at: index) else { return nil }
                index += 4
                if (0xD800..<0xDC00).contains(scalar), index + 6 <= raw.count, raw[index] == UInt8(ascii: "\\"),
                   raw[index + 1] == UInt8(ascii: "u"), let low = hexValue(raw, at: index + 2), (0xDC00..<0xE000).contains(low) {
                    scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
                    index += 6
                }
                result.append(contentsOf: String(Character(Unicode.Scalar(scalar) ?? "\u{FFFD}")).utf8)
            default:
                return nil
            }
        }
        return String(decoding: result, as: UTF8.self)
    }

    private func hexValue(_ raw: UnsafeRawBufferPointer, at index: Int) -> UInt32? {
        guard index + 4 <= raw.count else { return nil }
        var value: UInt32 = 0
        for byte in raw[index..<(index + 4)] {
            let digit: UInt8
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = byte - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = byte - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = byte - UInt8(ascii: "A") + 10
            default: return nil
            }
            value = value << 4 | UInt32(digit)
        }
        return value
    }
}
