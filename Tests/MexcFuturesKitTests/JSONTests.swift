import Foundation
import Testing
@testable import MexcFuturesKit

@Suite("JSON")
struct JSONTests {
    static let document = #"""
    { "id": 817027833053397504, "price": 83500.5, "negative": -42, "exponent": 1.5e3,
      "name": "BTC_USDT", "escaped": "a\"b\\c\/d\né🚀", "flag": true, "off": false, "none": null,
      "levels": [[83500.5, 120, 3], [83501, 0, 0]], "nested": {"inner": {"value": "deep"}}, "empty": {}, "list": [] }
    """#

    let json: JSON

    init() throws {
        json = try JSON(data: Data(Self.document.utf8))
    }

    @Test func readsNumbers() {
        #expect(json["id"].int64 == 817027833053397504)
        #expect(json["price"].double == 83500.5)
        #expect(json["price"].int64 == 83500)
        #expect(json["negative"].int == -42)
        #expect(json["exponent"].double == 1500)
        #expect(json["exponent"].int64 == 1500)
        #expect(json["id"].stringValue == "817027833053397504")
    }

    @Test func readsStrings() {
        #expect(json["name"].string == "BTC_USDT")
        #expect(json["escaped"].string == "a\"b\\c/d\né🚀")
        #expect(json["price"].string == nil)
    }

    @Test func readsLiterals() {
        #expect(json["flag"].bool == true)
        #expect(json["off"].bool == false)
        #expect(json["none"].exists == false)
        #expect(json["none"].string == nil)
    }

    @Test func readsContainers() {
        #expect(json["levels"][0][0].double == 83500.5)
        #expect(json["levels"][1][1].int == 0)
        #expect(json["levels"].arrayValue.count == 2)
        #expect(json["nested"]["inner"]["value"].string == "deep")
        #expect(json["empty"].dictionaryValue.isEmpty)
        #expect(json["list"].array?.isEmpty == true)
        #expect(json["nested"].dictionary?.keys.sorted() == ["inner"])
    }

    @Test func missingValuesFallBackToEmpty() {
        #expect(json["missing"].exists == false)
        #expect(json["missing"]["deeper"][3].stringValue == "")
        #expect(json["levels"][9].doubleValue == 0)
        #expect(json["name"][0].exists == false)
        #expect(json["levels"]["key"].exists == false)
    }

    @Test func numericStringsConvert() throws {
        let json = try JSON(data: Data(#"{"volume": "12.5", "id": "817027833053397504"}"#.utf8))

        #expect(json["volume"].double == 12.5)
        #expect(json["id"].int64 == 817027833053397504)
    }

    @Test func rawDataIsCompactJSON() {
        #expect(json["levels"][1].description == "[83501,0,0]")
        #expect(json["missing"].description == "null")
    }

    @Test(arguments: ["", "not json", "{", #"{"a":}"#, #"{"a":1,}"#, "[1 2]", #"{"a":"unterminated}"#, "tru", "{} {}"])
    func rejectsInvalidJSON(text: String) {
        #expect(throws: DecodingError.self) {
            try JSON(data: Data(text.utf8))
        }
    }

    @Test func acceptsTopLevelScalar() throws {
        #expect(try JSON(data: Data(" 42 ".utf8)).int == 42)
    }
}
