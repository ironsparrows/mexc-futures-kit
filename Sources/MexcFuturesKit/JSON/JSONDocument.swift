import Foundation
import yyjson

final class JSONDocument: @unchecked Sendable {
    private let pointer: UnsafeMutablePointer<yyjson_doc>

    private init(pointer: UnsafeMutablePointer<yyjson_doc>) {
        self.pointer = pointer
    }

    deinit {
        yyjson_doc_free(pointer)
    }

    static func parse(_ data: Data) -> JSONDocument? {
        data.withUnsafeBytes(parse)
    }

    static func parse(_ text: String) -> JSONDocument? {
        var text = text
        return text.withUTF8 { parse(UnsafeRawBufferPointer($0)) }
    }

    private static func parse(_ bytes: UnsafeRawBufferPointer) -> JSONDocument? {
        let text = UnsafeMutablePointer(mutating: bytes.baseAddress?.assumingMemoryBound(to: CChar.self))
        return yyjson_read_opts(text, bytes.count, 0, nil, nil).map(JSONDocument.init(pointer:))
    }

    func decode<Value>(_ body: (JSONNode) -> Value) -> Value {
        withExtendedLifetime(self) {
            body(JSONNode(document: self, pointer: yyjson_doc_get_root(pointer)))
        }
    }
}
