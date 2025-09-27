import Foundation

/// A macro that creates a union type from string literals, similar to TypeScript's literal union types.
///
/// This macro generates enum cases for each provided string literal and implements
/// `Codable` conformance with proper serialization/deserialization.
///
/// - Parameter literals: String literals to create union cases from
///
/// ## Usage
/// ```swift
/// struct Event: Codable {
///     @Union("click", "hover", "focus") enum EventType {}
///     let type: EventType
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
    names: named(rawValue),
    named(init),
    named(init(rawValue:)),
    named(init(from:)),
    named(encode(to:))
)
public macro Union(_ literals: String...) = #externalMacro(module: "TypeScriptBridgeMacros", type: "LiteralUnionMacro")

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
@attached(extension, conformances: Codable, names: named(init(from:)), named(encode(to:)))
public macro Union(_ types: Any.Type...) = #externalMacro(module: "TypeScriptBridgeMacros", type: "TypeUnionMacro")
