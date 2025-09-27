import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Public Access Modifier Tests

public struct PublicLiteralEvent: Codable {
    @Union("type1", "type2", "type3") public enum PublicType {}
    public let type: PublicType
}

public struct PublicUser: Codable {
    public let name: String
    public let age: Int
}

public struct PublicMessage: Codable {
    public let content: String
    public let timestamp: Date
}

@Union(PublicUser.self, PublicMessage.self) public enum PublicUnion {}

// MARK: - Internal Access Modifier Tests (default)

struct InternalLiteralEvent: Codable {
    @Union("internal1", "internal2", "internal3") enum InternalType {}
    let type: InternalType
}

struct InternalUser: Codable {
    let name: String
    let age: Int
}

struct InternalMessage: Codable {
    let content: String
    let timestamp: Date
}

@Union(InternalUser.self, InternalMessage.self) enum InternalUnion {}

// MARK: - Tests

@Test func testPublicLiteralUnionAccessModifiers() async throws {
    let event = PublicLiteralEvent(type: .type1)

    let encoder = JSONEncoder()
    let data = try encoder.encode(event)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(PublicLiteralEvent.self, from: data)

    #expect(decoded.type.rawValue == "type1")
}

@Test func testPublicTypeUnionAccessModifiers() async throws {
    let user = PublicUser(name: "Alice", age: 30)
    let union = PublicUnion.PublicUser(user)

    let encoder = JSONEncoder()
    let data = try encoder.encode(union)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(PublicUnion.self, from: data)

    switch decoded {
    case .PublicUser(let decodedUser):
        #expect(decodedUser.name == "Alice")
        #expect(decodedUser.age == 30)
    case .PublicMessage:
        #expect(Bool(false), "Expected PublicUser")
    }
}

@Test func testInternalLiteralUnionAccessModifiers() async throws {
    let event = InternalLiteralEvent(type: .internal1)

    let encoder = JSONEncoder()
    let data = try encoder.encode(event)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(InternalLiteralEvent.self, from: data)

    #expect(decoded.type.rawValue == "internal1")
}

@Test func testInternalTypeUnionAccessModifiers() async throws {
    let user = InternalUser(name: "Bob", age: 25)
    let union = InternalUnion.InternalUser(user)

    let encoder = JSONEncoder()
    let data = try encoder.encode(union)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(InternalUnion.self, from: data)

    switch decoded {
    case .InternalUser(let decodedUser):
        #expect(decodedUser.name == "Bob")
        #expect(decodedUser.age == 25)
    case .InternalMessage:
        #expect(Bool(false), "Expected InternalUser")
    }
}

@Test func testMixedAccessModifierCombinations() async throws {
    // Test that public types can work with internal types in JSON
    let publicUser = PublicUser(name: "Charlie", age: 35)
    let internalUser = InternalUser(name: "David", age: 40)

    let publicUnion = PublicUnion.PublicUser(publicUser)
    let internalUnion = InternalUnion.InternalUser(internalUser)

    let encoder = JSONEncoder()

    let publicData = try encoder.encode(publicUnion)
    let internalData = try encoder.encode(internalUnion)

    let decoder = JSONDecoder()

    let decodedPublic = try decoder.decode(PublicUnion.self, from: publicData)
    let decodedInternal = try decoder.decode(InternalUnion.self, from: internalData)

    switch decodedPublic {
    case .PublicUser(let user):
        #expect(user.name == "Charlie")
    case .PublicMessage:
        #expect(Bool(false), "Expected PublicUser")
    }

    switch decodedInternal {
    case .InternalUser(let user):
        #expect(user.name == "David")
    case .InternalMessage:
        #expect(Bool(false), "Expected InternalUser")
    }
}
