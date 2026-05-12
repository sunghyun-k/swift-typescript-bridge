import MacroTesting
import XCTest

@testable import TypeScriptBridgeMacros

final class TypeUnionExpansionTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(record: .missing, macros: ["Union": TypeUnionMacro.self]) {
            super.invokeTest()
        }
    }

    func testTwoTypeUnion() {
        assertMacro {
            #"""
            @Union(User.self, Organization.self)
            enum Entity {}
            """#
        } expansion: {
            #"""
            enum Entity {

                case user(User)

                case organization(Organization)
            }

            extension Entity: Codable {
                private struct AnyCodingKey: CodingKey {
                    var stringValue: String
                    var intValue: Int?

                    init?(stringValue: String) {
                        self.stringValue = stringValue
                        self.intValue = nil
                    }

                    init?(intValue: Int) {
                        self.stringValue = "\(intValue)"
                        self.intValue = intValue
                    }
                }
                init(from decoder: Decoder) throws {
                    typealias Type0 = User
                    typealias Type1 = Organization
                    if Type0.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type0(from: decoder) {
                            self = .user(decoded)
                            return
                }
            }
                    if Type1.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type1(from: decoder) {
                            self = .organization(decoded)
                            return
                }
            }
                    let container = try decoder.singleValueContainer()
                    if let value = try? container.decode(Type0.self) {
                        self = .user(value)
                        return
            }
                    if let value = try? container.decode(Type1.self) {
                        self = .organization(value)
                        return
            }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode union type from any of the possible cases")
                }
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
            case .user(let event):
                        try container.encode(event)
            case .organization(let event):
                        try container.encode(event)
            }
                }
            }
            """#
        }
    }

    func testThreeTypeUnion() {
        assertMacro {
            #"""
            @Union(PageView.self, Click.self, ErrorEvent.self)
            enum Event {}
            """#
        } expansion: {
            #"""
            enum Event {

                case pageView(PageView)

                case click(Click)

                case errorEvent(ErrorEvent)
            }

            extension Event: Codable {
                private struct AnyCodingKey: CodingKey {
                    var stringValue: String
                    var intValue: Int?

                    init?(stringValue: String) {
                        self.stringValue = stringValue
                        self.intValue = nil
                    }

                    init?(intValue: Int) {
                        self.stringValue = "\(intValue)"
                        self.intValue = intValue
                    }
                }
                init(from decoder: Decoder) throws {
                    typealias Type0 = PageView
                    typealias Type1 = Click
                    typealias Type2 = ErrorEvent
                    if Type0.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type0(from: decoder) {
                            self = .pageView(decoded)
                            return
                }
            }
                    if Type1.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type1(from: decoder) {
                            self = .click(decoded)
                            return
                }
            }
                    if Type2.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type2(from: decoder) {
                            self = .errorEvent(decoded)
                            return
                }
            }
                    let container = try decoder.singleValueContainer()
                    if let value = try? container.decode(Type0.self) {
                        self = .pageView(value)
                        return
            }
                    if let value = try? container.decode(Type1.self) {
                        self = .click(value)
                        return
            }
                    if let value = try? container.decode(Type2.self) {
                        self = .errorEvent(value)
                        return
            }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode union type from any of the possible cases")
                }
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
            case .pageView(let event):
                        try container.encode(event)
            case .click(let event):
                        try container.encode(event)
            case .errorEvent(let event):
                        try container.encode(event)
            }
                }
            }
            """#
        }
    }

    func testInvalidArgumentSuggestsAddingDotSelf() {
        assertMacro {
            #"""
            @Union(User, Organization.self)
            enum Entity {}
            """#
        } diagnostics: {
            """
            @Union(User, Organization.self)
                   ┬───
                   ├─ 🛑 Each @Union argument must be a type in `Type.self` form
                   │  ✏️ Append `.self` to refer to the type metatype
                   ╰─ 🛑 Each @Union argument must be a type in `Type.self` form
                      ✏️ Append `.self` to refer to the type metatype
            enum Entity {}
            """
        } fixes: {
            """
            @Union(User.self, Organization.self)
            enum Entity {}
            """
        } expansion: {
            #"""
            enum Entity {

                case user(User)

                case organization(Organization)
            }

            extension Entity: Codable {
                private struct AnyCodingKey: CodingKey {
                    var stringValue: String
                    var intValue: Int?

                    init?(stringValue: String) {
                        self.stringValue = stringValue
                        self.intValue = nil
                    }

                    init?(intValue: Int) {
                        self.stringValue = "\(intValue)"
                        self.intValue = intValue
                    }
                }
                init(from decoder: Decoder) throws {
                    typealias Type0 = User
                    typealias Type1 = Organization
                    if Type0.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type0(from: decoder) {
                            self = .user(decoded)
                            return
                }
            }
                    if Type1.self is any TypeDiscriminated.Type {
                        if let decoded = try? Type1(from: decoder) {
                            self = .organization(decoded)
                            return
                }
            }
                    let container = try decoder.singleValueContainer()
                    if let value = try? container.decode(Type0.self) {
                        self = .user(value)
                        return
            }
                    if let value = try? container.decode(Type1.self) {
                        self = .organization(value)
                        return
            }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Could not decode union type from any of the possible cases")
                }
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
            case .user(let event):
                        try container.encode(event)
            case .organization(let event):
                        try container.encode(event)
            }
                }
            }
            """#
        }
    }

    func testNoArgsDiagnoses() {
        assertMacro {
            #"""
            @Union()
            enum Empty {}
            """#
        } diagnostics: {
            """
            @Union()
            ┬───────
            ├─ 🛑 @Union requires at least one valid type argument (Type.self)
            ╰─ 🛑 @Union requires at least one valid type argument (Type.self)
            enum Empty {}
            """
        }
    }
}
