import Foundation

extension Result where Failure == MexcFuturesError {
    init(response: JSONNode, data: (JSONNode) -> Success?) {
        guard response["success"].boolValue else {
            self = .failure(.rejected(code: response["code"].intValue, message: response["message"].stringValue))
            return
        }
        guard let value = data(response["data"]) else {
            self = .failure(.malformedMessage(String(decoding: response.rawData() ?? Data(), as: UTF8.self)))
            return
        }
        self = .success(value)
    }
}
