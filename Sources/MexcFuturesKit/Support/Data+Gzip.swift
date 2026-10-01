import Foundation

enum GzipError: Error {
    case invalidHeader
    case truncated
}

extension Data {
    func gunzipped() throws -> Data {
        let bytes = [UInt8](self)
        guard bytes.count >= 18, bytes[0] == 0x1f, bytes[1] == 0x8b, bytes[2] == 8 else {
            throw GzipError.invalidHeader
        }
        let flags = bytes[3]
        var offset = 10
        if flags & 0x04 != 0 {
            guard offset + 2 <= bytes.count else { throw GzipError.truncated }
            offset += 2 + (Int(bytes[offset]) | Int(bytes[offset + 1]) << 8)
        }
        for flag: UInt8 in [0x08, 0x10] where flags & flag != 0 {
            guard offset < bytes.count, let terminator = bytes[offset...].firstIndex(of: 0) else { throw GzipError.truncated }
            offset = terminator + 1
        }
        if flags & 0x02 != 0 {
            offset += 2
        }
        guard offset + 8 <= bytes.count else { throw GzipError.truncated }
        return try (Data(bytes[offset..<(bytes.count - 8)]) as NSData).decompressed(using: .zlib) as Data
    }
}
