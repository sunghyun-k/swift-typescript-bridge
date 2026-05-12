import MacroTesting
import XCTest

@testable import TypeScriptBridgeMacros

final class LiteralUnionExpansionTests: XCTestCase {
    override func invokeTest() {
        // `record: .missing` lets new tests auto-populate their expectation on first run.
        // Set to `.all` to regenerate after intentional macro changes; reviewer confirms diff.
        withMacroTesting(record: .missing, macros: ["Union": LiteralUnionMacro.self]) {
            super.invokeTest()
        }
    }

    func testStringLiteralUnion() {
        assertMacro {
            #"""
            @Union("click", "hover", "focus")
            enum EventType {}
            """#
        } expansion: {
            """
            enum EventType {

                case `click`

                case `hover`

                case `focus`
            }

            extension EventType: Codable, Equatable {
                var rawValue: String {
                    switch self {
                    case .`click`:
                        return "click"
                    case .`hover`:
                        return "hover"
                    case .`focus`:
                        return "focus"
                    }
                }

                init?(rawValue: String) {
                    switch rawValue {
                    case "click":
                        self = .`click`
                    case "hover":
                        self = .`hover`
                    case "focus":
                        self = .`focus`
                    default:
                        return nil
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(String.self)
                    guard let value = Self(rawValue: rawValue) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    self = value
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(rawValue)
                }
            }
            """
        }
    }

    func testMixedTypeLiteralUnion() {
        assertMacro {
            #"""
            @Union("auto", 100, true, 2.5)
            enum ConfigValue {}
            """#
        } expansion: {
            """
            enum ConfigValue {

                case `auto`

                case `100`

                case `true`

                case `2.5`
            }

            extension ConfigValue: Codable, Equatable {
                var rawValue: any _LiteralType {
                    switch self {
                    case .`auto`:
                        return "auto"
                    case .`100`:
                        return 100
                    case .`true`:
                        return true
                    case .`2.5`:
                        return 2.5
                    }
                }

                init?(rawValue: any _LiteralType) {
                    if let value = rawValue as? String, value == "auto" {
                        self = .`auto`;
                        return
                    }
                    if let value = rawValue as? Int, value == 100 {
                        self = .`100`;
                        return
                    }
                    if let value = rawValue as? Bool, value == true {
                        self = .`true`;
                        return
                    }
                    if let value = rawValue as? Double, value == 2.5 {
                        self = .`2.5`;
                        return
                    }
                    return nil
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let value = try? container.decode(String.self), value == "auto" {
                        self = .`auto`;
                        return
                    }
                    if let value = try? container.decode(Int.self), value == 100 {
                        self = .`100`;
                        return
                    }
                    if let value = try? container.decode(Bool.self), value == true {
                        self = .`true`;
                        return
                    }
                    if let value = try? container.decode(Double.self), value == 2.5 {
                        self = .`2.5`;
                        return
                    }
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(rawValue)
                }
            }
            """
        }
    }

    func testNullableLiteralUnion() {
        assertMacro {
            #"""
            @Union("a", "b", nil)
            enum MaybeAB {}
            """#
        } expansion: {
            """
            enum MaybeAB {

                case `a`

                case `b`

                case `null`
            }

            extension MaybeAB: Codable, Equatable {
                var rawValue: String? {
                    switch self {
                    case .`a`:
                        return "a"
                    case .`b`:
                        return "b"
                    case .`null`:
                        return nil
                    }
                }

                init?(rawValue: String?) {
                    switch rawValue {
                    case .none:
                        self = .`null`
                    case .some("a"):
                        self = .`a`
                    case .some("b"):
                        self = .`b`
                    default:
                        return nil
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if container.decodeNil() {
                        self = .`null`
                        return
                    }
                    let rawValue = try container.decode(String.self)
                    guard let value = Self(rawValue: rawValue) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    self = value
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    if case .`null` = self {
                        try container.encodeNil()
                    } else {
                        try container.encode(rawValue!)
                    }
                }
            }
            """
        }
    }

    func testNullableMixedLiteralUnion() {
        assertMacro {
            #"""
            @Union("auto", 100, true, nil)
            enum MaybeConfig {}
            """#
        } expansion: {
            """
            enum MaybeConfig {

                case `auto`

                case `100`

                case `true`

                case `null`
            }

            extension MaybeConfig: Codable, Equatable {
                var rawValue: (any _LiteralType)? {
                    switch self {
                    case .`auto`:
                        return "auto"
                    case .`100`:
                        return 100
                    case .`true`:
                        return true
                    case .`null`:
                        return nil
                    }
                }

                init?(rawValue: (any _LiteralType)?) {
                    if rawValue == nil {
                        self = .`null`;
                        return
                    }
                    if let value = rawValue as? String, value == "auto" {
                        self = .`auto`;
                        return
                    }
                    if let value = rawValue as? Int, value == 100 {
                        self = .`100`;
                        return
                    }
                    if let value = rawValue as? Bool, value == true {
                        self = .`true`;
                        return
                    }
                    return nil
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if container.decodeNil() {
                        self = .`null`;
                        return
                    }
                    if let value = try? container.decode(String.self), value == "auto" {
                        self = .`auto`;
                        return
                    }
                    if let value = try? container.decode(Int.self), value == 100 {
                        self = .`100`;
                        return
                    }
                    if let value = try? container.decode(Bool.self), value == true {
                        self = .`true`;
                        return
                    }
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    if case .`null` = self {
                try container.encodeNil()
                    } else if let value = rawValue {
                try container.encode(value)
                    } else {
                try container.encodeNil()
                    }
                }
            }
            """
        }
    }

    func testNumericLiteralUnion() {
        assertMacro {
            #"""
            @Union(200, 404, 500)
            enum HTTPStatus {}
            """#
        } expansion: {
            """
            enum HTTPStatus {

                case `200`

                case `404`

                case `500`
            }

            extension HTTPStatus: Codable, Equatable {
                var rawValue: Int {
                    switch self {
                    case .`200`:
                        return 200
                    case .`404`:
                        return 404
                    case .`500`:
                        return 500
                    }
                }

                init?(rawValue: Int) {
                    switch rawValue {
                    case 200:
                        self = .`200`
                    case 404:
                        self = .`404`
                    case 500:
                        self = .`500`
                    default:
                        return nil
                    }
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(Int.self)
                    guard let value = Self(rawValue: rawValue) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    self = value
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(rawValue)
                }
            }
            """
        }
    }

    func testPublicAccessModifier() {
        assertMacro {
            #"""
            @Union("a", "b")
            public enum Kind {}
            """#
        } expansion: {
            """
            public enum Kind {

                public case `a`

                public case `b`
            }

            extension Kind: Codable, Equatable {
                public var rawValue: String {
                    switch self {
                    case .`a`:
                        return "a"
                    case .`b`:
                        return "b"
                    }
                }

                public init?(rawValue: String) {
                    switch rawValue {
                    case "a":
                        self = .`a`
                    case "b":
                        self = .`b`
                    default:
                        return nil
                    }
                }

                public init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(String.self)
                    guard let value = Self(rawValue: rawValue) else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid value"))
                    }
                    self = value
                }

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(rawValue)
                }
            }
            """
        }
    }

    func testUnionOnNonEnumDiagnoses() {
        assertMacro {
            #"""
            @Union("a", "b")
            struct NotAnEnum {}
            """#
        } diagnostics: {
            """
            @Union("a", "b")
            ├─ 🛑 @Union can only be applied to enum declarations
            ╰─ 🛑 @Union can only be applied to enum declarations
            struct NotAnEnum {}
            """
        }
    }

    func testEmptyUnionDiagnoses() {
        assertMacro {
            #"""
            @Union()
            enum Nothing {}
            """#
        } diagnostics: {
            """
            @Union()
            ┬───────
            ├─ 🛑 @Union requires at least one valid literal (String, Int, Double, Bool, or nil)
            ╰─ 🛑 @Union requires at least one valid literal (String, Int, Double, Bool, or nil)
            enum Nothing {}
            """
        }
    }
}
