import MacroTesting
import XCTest

@testable import TypeScriptBridgeMacros

final class UnionDiscriminatorExpansionTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            record: .missing,
            macros: ["UnionDiscriminator": UnionDiscriminatorMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testDiscriminatorAddsTypealias() {
        assertMacro {
            #"""
            @UnionDiscriminator("type")
            struct ClickEvent: Codable {
                enum EventType { case click }
                var type: EventType
                var x: Int
            }
            """#
        } expansion: {
            """
            struct ClickEvent: Codable {
                enum EventType { case click 
            }
                var type: EventType
                var x: Int
            }

            extension ClickEvent: TypeDiscriminated {
                typealias DiscriminatorType = EventType
                static let discriminatorKey = "type"
            }
            """
        }
    }

    func testFieldNotFoundDiagnoses() {
        assertMacro {
            #"""
            @UnionDiscriminator("missing")
            struct Foo: Codable {
                var x: Int
            }
            """#
        } diagnostics: {
            """
            @UnionDiscriminator("missing")
            ┬─────────────────────────────
            ╰─ 🛑 Property 'missing' not found in struct. @UnionDiscriminator expects the named property to be declared on the same struct.
            struct Foo: Codable {
                var x: Int
            }
            """
        }
    }

    func testLabeledArgumentSuggestsDroppingLabel() {
        assertMacro {
            #"""
            @UnionDiscriminator(property: "type")
            struct Foo: Codable {
                enum EventType { case click }
                var type: EventType
            }
            """#
        } diagnostics: {
            """
            @UnionDiscriminator(property: "type")
                                ┬───────────────
                                ╰─ 🛑 @UnionDiscriminator expects an unlabeled argument. Use @UnionDiscriminator("type") not @UnionDiscriminator(property: "type")
                                   ✏️ Drop the argument label
            struct Foo: Codable {
                enum EventType { case click }
                var type: EventType
            }
            """
        } fixes: {
            """
            @UnionDiscriminator("type")
            struct Foo: Codable {
                enum EventType { case click }
                var type: EventType
            }
            """
        } expansion: {
            """
            struct Foo: Codable {
                enum EventType { case click 
            }
                var type: EventType
            }

            extension Foo: TypeDiscriminated {
                typealias DiscriminatorType = EventType
                static let discriminatorKey = "type"
            }
            """
        }
    }
}
