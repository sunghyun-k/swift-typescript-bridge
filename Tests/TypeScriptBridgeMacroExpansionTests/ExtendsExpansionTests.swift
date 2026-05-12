import MacroTesting
import XCTest

@testable import TypeScriptBridgeMacros

final class ExtendsExpansionTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(record: .missing, macros: ["Extends": ExtendsMacro.self]) {
            super.invokeTest()
        }
    }

    func testSingleParentExtends() {
        assertMacro {
            #"""
            @Extends(BaseEvent.self)
            struct ClickEvent {
                var x: Int
                var y: Int
            }
            """#
        } expansion: {
            #"""
            struct ClickEvent {
                var x: Int
                var y: Int

                var _parent: BaseEvent

                init(_ parent: BaseEvent, x: Int, y: Int) {
                    self._parent = parent
                    self.x = x
                    self.y = y
                }
            }

            extension ClickEvent: Codable, _ExtendsParent {
                private enum CodingKeys: String, CodingKey {
                    case x;
                    case y
                }

                init(from decoder: Decoder) throws {
                    do {
                self._parent = try BaseEvent(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                where ctx.codingPath.last.flatMap({
                            CodingKeys(stringValue: $0.stringValue)
                        }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: "Property '\(key)' override conflict: parent's declared type (\(expected)) is incompatible with the JSON value. The child redeclares '\(key)' — ensure parent and child share a JSON representation.",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.x = try container.decode(Int.self, forKey: .x)
                self.y = try container.decode(Int.self, forKey: .y)
                }

                func encode(to encoder: Encoder) throws {
                    try _parent.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(x, forKey: .x)
                try container.encode(y, forKey: .y)
                }
            }
            """#
        }
    }

    func testMultiParentExtends() {
        assertMacro {
            #"""
            @Extends(Identified.self, Timestamped.self)
            struct Article {
                var title: String
            }
            """#
        } expansion: {
            #"""
            struct Article {
                var title: String

                var _parent1: Identified

                var _parent2: Timestamped

                init(_ parent1: Identified, _ parent2: Timestamped, title: String) {
                    self._parent1 = parent1
                    self._parent2 = parent2
                    self.title = title
                }
            }

            extension Article: Codable, _ExtendsParents {
                private enum CodingKeys: String, CodingKey {
                    case title
                }

                subscript <__ExtendsT>(dynamicMember keyPath: WritableKeyPath<Identified, __ExtendsT>) -> __ExtendsT {
                get {
                    _parent1[keyPath: keyPath]
                }
                set {
                    _parent1[keyPath: keyPath] = newValue
                }
                }
                subscript <__ExtendsT>(dynamicMember keyPath: KeyPath<Identified, __ExtendsT>) -> __ExtendsT {
                    _parent1[keyPath: keyPath]
                }

                subscript <__ExtendsT>(dynamicMember keyPath: WritableKeyPath<Timestamped, __ExtendsT>) -> __ExtendsT {
                get {
                    _parent2[keyPath: keyPath]
                }
                set {
                    _parent2[keyPath: keyPath] = newValue
                }
                }
                subscript <__ExtendsT>(dynamicMember keyPath: KeyPath<Timestamped, __ExtendsT>) -> __ExtendsT {
                    _parent2[keyPath: keyPath]
                }

                init(from decoder: Decoder) throws {
                    do {
                self._parent1 = try Identified(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                where ctx.codingPath.last.flatMap({
                            CodingKeys(stringValue: $0.stringValue)
                        }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: "Property '\(key)' override conflict: parent Identified's declared type (\(expected)) is incompatible with the JSON value. The child redeclares '\(key)' — ensure parent and child share a JSON representation.",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                do {
                self._parent2 = try Timestamped(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                where ctx.codingPath.last.flatMap({
                            CodingKeys(stringValue: $0.stringValue)
                        }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: "Property '\(key)' override conflict: parent Timestamped's declared type (\(expected)) is incompatible with the JSON value. The child redeclares '\(key)' — ensure parent and child share a JSON representation.",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.title = try container.decode(String.self, forKey: .title)
                }

                func encode(to encoder: Encoder) throws {
                    try _parent1.encode(to: encoder)
                try _parent2.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(title, forKey: .title)
                }
            }
            """#
        }
    }

    func testExtendsWithNoOwnProperties() {
        assertMacro {
            #"""
            @Extends(BaseEvent.self)
            struct EmptyChild {}
            """#
        } expansion: {
            """
            struct EmptyChild {

                var _parent: BaseEvent

                init(_ parent: BaseEvent) {
                    self._parent = parent
                }
            }

            extension EmptyChild: Codable, _ExtendsParent {


                init(from decoder: Decoder) throws {
                    self._parent = try BaseEvent(from: decoder)
                }

                func encode(to encoder: Encoder) throws {
                    try _parent.encode(to: encoder)
                }
            }
            """
        }
    }

    func testExtendsWithOptionalChildField() {
        assertMacro {
            #"""
            @Extends(BaseEvent.self)
            struct ClickEvent {
                var label: String?
            }
            """#
        } expansion: {
            #"""
            struct ClickEvent {
                var label: String?

                var _parent: BaseEvent

                init(_ parent: BaseEvent, label: String?) {
                    self._parent = parent
                    self.label = label
                }
            }

            extension ClickEvent: Codable, _ExtendsParent {
                private enum CodingKeys: String, CodingKey {
                    case label
                }

                init(from decoder: Decoder) throws {
                    do {
                self._parent = try BaseEvent(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                where ctx.codingPath.last.flatMap({
                            CodingKeys(stringValue: $0.stringValue)
                        }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: "Property '\(key)' override conflict: parent's declared type (\(expected)) is incompatible with the JSON value. The child redeclares '\(key)' — ensure parent and child share a JSON representation.",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.label = try container.decodeIfPresent(String.self, forKey: .label)
                }

                func encode(to encoder: Encoder) throws {
                    try _parent.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(label, forKey: .label)
                }
            }
            """#
        }
    }

    func testInvalidParentSuggestsAddingDotSelf() {
        assertMacro {
            #"""
            @Extends(BaseEvent)
            struct Foo {
                var x: Int
            }
            """#
        } diagnostics: {
            """
            @Extends(BaseEvent)
                     ┬────────
                     ├─ 🛑 Each @Extends argument must be a type in `Type.self` form
                     │  ✏️ Append `.self` to refer to the type metatype
                     ╰─ 🛑 Each @Extends argument must be a type in `Type.self` form
                        ✏️ Append `.self` to refer to the type metatype
            struct Foo {
                var x: Int
            }
            """
        } fixes: {
            """
            @Extends(BaseEvent.self)
            struct Foo {
                var x: Int
            }
            """
        } expansion: {
            #"""
            struct Foo {
                var x: Int

                var _parent: BaseEvent

                init(_ parent: BaseEvent, x: Int) {
                    self._parent = parent
                    self.x = x
                }
            }

            extension Foo: Codable, _ExtendsParent {
                private enum CodingKeys: String, CodingKey {
                    case x
                }

                init(from decoder: Decoder) throws {
                    do {
                self._parent = try BaseEvent(from: decoder)
                    } catch let DecodingError.typeMismatch(expected, ctx)
                where ctx.codingPath.last.flatMap({
                            CodingKeys(stringValue: $0.stringValue)
                        }) != nil
                    {
                        let key = ctx.codingPath.last!.stringValue
                        throw DecodingError.typeMismatch(
                            expected,
                            DecodingError.Context(
                                codingPath: ctx.codingPath,
                                debugDescription: "Property '\(key)' override conflict: parent's declared type (\(expected)) is incompatible with the JSON value. The child redeclares '\(key)' — ensure parent and child share a JSON representation.",
                                underlyingError: ctx.underlyingError
                            )
                        )
                    }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.x = try container.decode(Int.self, forKey: .x)
                }

                func encode(to encoder: Encoder) throws {
                    try _parent.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(x, forKey: .x)
                }
            }
            """#
        }
    }

    func testNoArgsDiagnoses() {
        assertMacro {
            #"""
            @Extends()
            struct Foo {
                var x: Int
            }
            """#
        } diagnostics: {
            """
            @Extends()
            ┬─────────
            ├─ 🛑 @Extends requires at least one parent type in `Type.self` form (e.g. @Extends(Parent.self))
            ╰─ 🛑 @Extends requires at least one parent type in `Type.self` form (e.g. @Extends(Parent.self))
            struct Foo {
                var x: Int
            }
            """
        }
    }
}
