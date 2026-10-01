import Crypto
import Foundation

struct RequestSignature: Equatable {
    let nonce: String
    let sign: String

    init(body: String, authToken: String, timestamp: String) {
        let key = Insecure.MD5.hash(data: Data((authToken + timestamp).utf8)).hexEncodedString.dropFirst(7)
        nonce = timestamp
        sign = Insecure.MD5.hash(data: Data((timestamp + body + key).utf8)).hexEncodedString
    }
}

func hmacSHA256(_ message: String, secret: String) -> String {
    HMAC<SHA256>
        .authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: Data(secret.utf8)))
        .hexEncodedString
}

extension Sequence<UInt8> {
    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
