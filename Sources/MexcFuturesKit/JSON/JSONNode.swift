import Foundation
import yyjson

struct JSONNode {
    unowned(unsafe) let document: JSONDocument
    let pointer: UnsafeMutablePointer<yyjson_val>?

    subscript(key: StaticString) -> JSONNode {
        key.withUTF8Buffer { key in
            member(UnsafeRawPointer(key.baseAddress)?.assumingMemoryBound(to: CChar.self), count: key.count)
        }
    }

    subscript(key: String) -> JSONNode {
        var key = key
        return key.withUTF8 { key in
            member(UnsafeRawPointer(key.baseAddress)?.assumingMemoryBound(to: CChar.self), count: key.count)
        }
    }

    subscript(index: Int) -> JSONNode {
        JSONNode(document: document, pointer: index >= 0 ? yyjson_arr_get(pointer, index) : nil)
    }

    var exists: Bool {
        pointer != nil && !yyjson_is_null(pointer)
    }

    var isObject: Bool {
        yyjson_is_obj(pointer)
    }

    var string: String? {
        guard let characters = yyjson_get_str(pointer) else { return nil }
        return String(decoding: UnsafeRawBufferPointer(start: characters, count: yyjson_get_len(pointer)), as: UTF8.self)
    }

    var numberText: String? {
        if yyjson_is_sint(pointer) { return String(yyjson_get_sint(pointer)) }
        if yyjson_is_uint(pointer) { return String(yyjson_get_uint(pointer)) }
        if yyjson_is_real(pointer) { return String(yyjson_get_real(pointer)) }
        return nil
    }

    var int64: Int64? {
        if yyjson_is_sint(pointer) { return yyjson_get_sint(pointer) }
        if yyjson_is_uint(pointer) { return Int64(exactly: yyjson_get_uint(pointer)) }
        if yyjson_is_real(pointer) { return Int64(exactly: yyjson_get_real(pointer).rounded(.towardZero)) }
        return string.flatMap(Int64.init)
    }

    var int: Int? {
        int64.map(Int.init(truncatingIfNeeded:))
    }

    var double: Double? {
        yyjson_is_num(pointer) ? yyjson_get_num(pointer) : string.flatMap(Double.init)
    }

    var bool: Bool? {
        if yyjson_is_bool(pointer) { return yyjson_get_bool(pointer) }
        return yyjson_is_num(pointer) ? yyjson_get_num(pointer) != 0 : nil
    }

    var date: Date? {
        int64.map { Date(timeIntervalSince1970: Double($0) / 1000) }
    }

    func map<Element>(_ transform: (JSONNode) -> Element) -> [Element]? {
        guard yyjson_is_arr(pointer) else { return nil }
        var elements: [Element] = []
        elements.reserveCapacity(yyjson_arr_size(pointer))
        var iterator = yyjson_arr_iter()
        yyjson_arr_iter_init(pointer, &iterator)
        while let element = yyjson_arr_iter_next(&iterator) {
            elements.append(transform(JSONNode(document: document, pointer: element)))
        }
        return elements
    }

    func members() -> [(key: String, value: JSONNode)]? {
        guard yyjson_is_obj(pointer) else { return nil }
        var members: [(key: String, value: JSONNode)] = []
        members.reserveCapacity(yyjson_obj_size(pointer))
        var iterator = yyjson_obj_iter()
        yyjson_obj_iter_init(pointer, &iterator)
        while let key = yyjson_obj_iter_next(&iterator) {
            let value = JSONNode(document: document, pointer: yyjson_obj_iter_get_val(key))
            members.append((JSONNode(document: document, pointer: key).string ?? "", value))
        }
        return members
    }

    func rawData() -> Data? {
        var length = 0
        guard let text = yyjson_val_write(pointer, 0, &length) else { return nil }
        return Data(bytesNoCopy: text, count: length, deallocator: .free)
    }

    private func member(_ key: UnsafePointer<CChar>?, count: Int) -> JSONNode {
        JSONNode(document: document, pointer: yyjson_obj_getn(pointer, key, count))
    }
}
