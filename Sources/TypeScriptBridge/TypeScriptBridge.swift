import Foundation

/// A macro that creates a union type from literal values, similar to TypeScript's literal union types.
///
/// This macro generates enum cases for each provided literal and implements
/// `Codable` and `Equatable` conformance with proper serialization/deserialization.
///
/// - Parameter literals: Literal values (String, Int, Double, Bool) to create union cases from
///
/// ## Usage
/// ```swift
/// // String literals
/// struct Event: Codable {
///     @Union("click", "hover", "focus") enum EventType {}
///     let type: EventType
/// }
///
/// // Numeric literals
/// struct Response: Codable {
///     @Union(200, 404, 500) enum StatusCode {}
///     let statusCode: StatusCode
/// }
///
/// // Boolean literals
/// struct Setting: Codable {
///     @Union(true, false) enum IsEnabled {}
///     let enabled: IsEnabled
/// }
///
/// // Mixed type literals
/// struct Config: Codable {
///     @Union("auto", 100, true, 2.5, "manual", false) enum Value {}
///     let value: Value
/// }
/// ```
///
/// ## Access Modifiers
/// The macro respects the access modifier of the enum:
/// ```swift
/// public struct PublicEvent: Codable {
///     @Union("public", "internal") public enum AccessType {}
///     public let type: AccessType
/// }
/// ```
///
/// ## Special Characters
/// Supports any character including Unicode, emojis, and Swift keywords:
/// ```swift
/// @Union("class", "func", "🎉", "한국어", "123invalid") enum SpecialCases {}
/// ```
@attached(member, names: arbitrary)
@attached(
    extension,
    conformances: Codable,
    Equatable,
    names: named(rawValue),
    named(init),
    named(init(rawValue:)),
    named(init(from:)),
    named(encode(to:))
)
public macro Union(_ literals: (any _LiteralType)?...) =
    #externalMacro(module: "TypeScriptBridgeMacros", type: "LiteralUnionMacro")

/// A macro that creates a union type from Swift types, similar to TypeScript's union types.
///
/// This macro generates enum cases for each provided type and implements
/// `Codable` conformance that tries to decode each type in order.
///
/// - Parameter types: Swift types to create union cases from
///
/// ## Usage
/// ```swift
/// struct User: Codable {
///     let name: String
/// }
///
/// struct Organization: Codable {
///     let name: String
///     let memberCount: Int
/// }
///
/// @Union(User.self, Organization.self) enum Entity {}
/// ```
///
/// ## JSON Handling
/// The macro attempts to decode JSON as each type in the order specified:
/// ```swift
/// // Will decode as User if JSON has only "name"
/// // Will decode as Organization if JSON has "name" and "memberCount"
/// let entity: Entity = try JSONDecoder().decode(Entity.self, from: jsonData)
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: Codable, names: named(init(from:)), named(encode(to:)), named(AnyCodingKey))
public macro Union(_ types: Any.Type...) = #externalMacro(module: "TypeScriptBridgeMacros", type: "TypeUnionMacro")

/// A macro that marks a type as discriminated for use in type unions.
///
/// This macro analyzes the specified property to extract discriminator information
/// and automatically implements the `TypeDiscriminated` protocol.
///
/// - Parameter _: The name of the discriminator property (e.g., "type")
///
/// ## Usage
/// ```swift
/// @UnionDiscriminator("type")
/// struct ClickEvent: Codable {
///     @Union("click") enum EventType {}
///     let type: EventType
///     var coordinates: [String]
/// }
///
/// @Union(ClickEvent.self, KeyboardEvent.self)
/// enum UIEvent {}
/// ```
@attached(extension, conformances: TypeDiscriminated, names: named(DiscriminatorType), named(discriminatorKey))
public macro UnionDiscriminator(_ property: String) =
    #externalMacro(module: "TypeScriptBridgeMacros", type: "UnionDiscriminatorMacro")

/// Protocol for types that can be discriminated in a union by a specific field value.
///
/// Types conforming to this protocol provide information about which field
/// and which type identify them in a discriminated union.
public protocol TypeDiscriminated {
    /// The type of the discriminator field (e.g., EventType enum)
    associatedtype DiscriminatorType: Decodable, Equatable
    /// The name of the field used for discrimination (e.g., "type")
    static var discriminatorKey: String { get }
}

public protocol _LiteralType: Codable, Equatable {}
extension String: _LiteralType {}
extension Int: _LiteralType {}
extension Double: _LiteralType {}
extension Bool: _LiteralType {}

/// Internal-use protocol that enables implicit keypath forwarding for `@Extends`-decorated
/// structs with a single parent. Users do not conform to this directly — `@Extends` adds
/// the conformance.
@dynamicMemberLookup
public protocol _ExtendsParent {
    associatedtype Parent
    var _parent: Parent { get set }
}

extension _ExtendsParent {
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Parent, T>) -> T {
        get { _parent[keyPath: keyPath] }
        set { _parent[keyPath: keyPath] = newValue }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Parent, T>) -> T {
        _parent[keyPath: keyPath]
    }
}

// MARK: - Automatic TypeDiscriminated forwarding for @Extends(SingleParent.self)

/// If you `@Extends` a parent that is already `@UnionDiscriminator`-marked, an empty
/// `extension Child: TypeDiscriminated {}` is enough — `discriminatorKey` and
/// `DiscriminatorType` are forwarded from the parent automatically.
extension _ExtendsParent where Parent: TypeDiscriminated {
    public typealias DiscriminatorType = Parent.DiscriminatorType
    public static var discriminatorKey: String { Parent.discriminatorKey }
}

/// Marker protocol for `@Extends` with two or more parents. Carries
/// `@dynamicMemberLookup`; the macro emits per-parent keypath subscripts directly in the
/// generated extension. Users do not conform to this directly.
@dynamicMemberLookup
public protocol _ExtendsParents {
    // Marker. Concrete subscripts are macro-generated per parent type.
    // A do-nothing default subscript is provided so the protocol itself is well-formed;
    // it is shadowed by the macro-generated overloads on the conforming type.
    subscript(dynamicMember _: KeyPath<Never, Never>) -> Never { get }
}

extension _ExtendsParents {
    public subscript(dynamicMember keyPath: KeyPath<Never, Never>) -> Never {
        fatalError("unreachable: Never has no keypaths")
    }
}

/// A macro that gives a struct TypeScript-style `extends` semantics: stored parent(s),
/// flat JSON Codable, and keypath forwarding to parent properties.
///
/// - Parameter parents: One or more parent types (e.g. `ParentType.self`,
///   or `A.self, B.self` for multiple parents).
///
/// ## Single Parent
/// ```swift
/// struct BaseEvent: Codable {
///     var timestamp: Double
/// }
///
/// @Extends(BaseEvent.self)
/// struct ClickEvent {
///     var x: Int
///     var y: Int
/// }
///
/// let c = ClickEvent(BaseEvent(timestamp: 0), x: 1, y: 2)
/// c.timestamp  // forwarded from BaseEvent
/// c.x          // 1
/// // JSON: {"timestamp":0,"x":1,"y":2}
/// ```
///
/// ## Multiple Parents
/// ```swift
/// struct Identified: Codable { var id: String }
/// struct Timestamped: Codable { var createdAt: Double }
///
/// @Extends(Identified.self, Timestamped.self)
/// struct Article {
///     var title: String
/// }
///
/// let a = Article(Identified(id: "x"), Timestamped(createdAt: 0), title: "Hi")
/// a.id          // forwarded from Identified
/// a.createdAt   // forwarded from Timestamped
/// a.title       // own
/// // JSON: {"id":"x","createdAt":0,"title":"Hi"}
/// ```
///
/// When two parents declare the same JSON key, the later-listed parent wins on encode
/// (it writes after the earlier one) and on decode (both read from the same container;
/// the later assignment overwrites). Child-owned properties always shadow parents.
@attached(member, names: arbitrary)
@attached(
    extension,
    conformances: Codable,
    _ExtendsParent,
    _ExtendsParents,
    names: named(init(from:)),
    named(encode(to:)),
    named(CodingKeys),
    named(subscript(dynamicMember:))
)
public macro Extends(_ parents: Any.Type...) =
    #externalMacro(module: "TypeScriptBridgeMacros", type: "ExtendsMacro")
