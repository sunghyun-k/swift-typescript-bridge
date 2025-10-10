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
public macro Union(_ literals: any _LiteralType...) =
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
