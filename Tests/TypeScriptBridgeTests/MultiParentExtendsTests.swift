import Foundation
import Testing

@testable import TypeScriptBridge

// MARK: - Multi-parent @Extends fixtures

struct MultiParentIdentified: Codable, Equatable {
    var id: String
}

struct MultiParentTimestamped: Codable, Equatable {
    var createdAt: Double
    var updatedAt: Double
}

@Extends(MultiParentIdentified.self, MultiParentTimestamped.self)
struct MultiParentArticle: Equatable {
    var title: String
    var body: String
}

// MARK: - Tests

@Test func testMultiParentInitStoresAllParents() async throws {
    let article = MultiParentArticle(
        MultiParentIdentified(id: "a-1"),
        MultiParentTimestamped(createdAt: 1.0, updatedAt: 2.0),
        title: "Hi",
        body: "There"
    )
    #expect(article._parent1.id == "a-1")
    #expect(article._parent2.createdAt == 1.0)
    #expect(article._parent2.updatedAt == 2.0)
    #expect(article.title == "Hi")
    #expect(article.body == "There")
}

@Test func testMultiParentDynamicMemberLookupForwardsToCorrectParent() async throws {
    let article = MultiParentArticle(
        MultiParentIdentified(id: "a-1"),
        MultiParentTimestamped(createdAt: 1.0, updatedAt: 2.0),
        title: "Hi",
        body: "There"
    )
    // Forwarded from _parent1
    #expect(article.id == "a-1")
    // Forwarded from _parent2
    #expect(article.createdAt == 1.0)
    #expect(article.updatedAt == 2.0)
}

@Test func testMultiParentEncodesAllKeysFlatly() async throws {
    let article = MultiParentArticle(
        MultiParentIdentified(id: "a-1"),
        MultiParentTimestamped(createdAt: 1.0, updatedAt: 2.0),
        title: "Hi",
        body: "There"
    )
    let data = try JSONEncoder().encode(article)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("\"id\":\"a-1\""))
    #expect(json.contains("\"createdAt\":1"))
    #expect(json.contains("\"updatedAt\":2"))
    #expect(json.contains("\"title\":\"Hi\""))
    #expect(json.contains("\"body\":\"There\""))
    // No nested parent objects.
    #expect(!json.contains("\"_parent\""))
    #expect(!json.contains("\"_parent1\""))
    #expect(!json.contains("\"_parent2\""))
}

@Test func testMultiParentRoundtripsThroughFlatJSON() async throws {
    let jsonString = """
        {
            "id": "a-1",
            "createdAt": 100.5,
            "updatedAt": 200.5,
            "title": "Hello",
            "body": "World"
        }
        """
    let decoded = try decodeFromJSON(MultiParentArticle.self, from: jsonString)
    #expect(decoded.id == "a-1")
    #expect(decoded.createdAt == 100.5)
    #expect(decoded.updatedAt == 200.5)
    #expect(decoded.title == "Hello")
    #expect(decoded.body == "World")
}

// MARK: - No own properties

@Extends(MultiParentIdentified.self, MultiParentTimestamped.self)
struct MultiParentNoOwnProps {}

@Test func testMultiParentNoOwnPropsRoundtrips() async throws {
    let value = MultiParentNoOwnProps(
        MultiParentIdentified(id: "x"),
        MultiParentTimestamped(createdAt: 0, updatedAt: 0)
    )
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(MultiParentNoOwnProps.self, from: data)
    #expect(decoded.id == "x")
}

// MARK: - Override in multi-parent context

struct MultiParentBaseA: Codable, Equatable {
    var kind: String
    var common: String
}

struct MultiParentBaseB: Codable, Equatable {
    var extra: Int
}

@Extends(MultiParentBaseA.self, MultiParentBaseB.self)
struct MultiParentChildOverride: Equatable {
    @Union("specific") enum Kind {}
    var kind: Kind  // narrows BaseA.kind: String → literal
    var ownField: Int
}

@Test func testMultiParentChildOverrideShadowsParent() async throws {
    let c = MultiParentChildOverride(
        MultiParentBaseA(kind: "ignored", common: "shared"),
        MultiParentBaseB(extra: 42),
        kind: .specific,
        ownField: 7
    )
    // Child's `kind` (literal enum) shadows the parent's String.
    #expect(c.kind == .specific)
    // Parent still has its own value reachable via _parent1.
    #expect(c._parent1.kind == "ignored")
    // Other parent fields forwarded.
    #expect(c.common == "shared")
    #expect(c.extra == 42)
}

@Test func testMultiParentDecodeWithChildKindWins() async throws {
    let json = """
        {
            "kind": "specific",
            "common": "shared",
            "extra": 42,
            "ownField": 7
        }
        """
    let decoded = try decodeFromJSON(MultiParentChildOverride.self, from: json)
    #expect(decoded.kind == .specific)
    #expect(decoded.ownField == 7)
}

@Test func testMultiParentDecodeRejectsInvalidLiteralForChildOverride() async throws {
    let json = """
        {
            "kind": "wrong",
            "common": "shared",
            "extra": 42,
            "ownField": 7
        }
        """
    #expect(throws: (any Error).self) {
        _ = try decodeFromJSON(MultiParentChildOverride.self, from: json)
    }
}
