import Foundation
import Testing
@testable import TypeScriptBridge

struct ExtendsBase: Codable, Equatable {
    var name: String
}

@Extends(ExtendsBase.self)
@dynamicMemberLookup
struct ExtendsChild: Equatable {
    var number: Int
}

@Test func testExtendsGeneratesParentStorageAndConvenienceInit() async throws {
    let c = ExtendsChild(ExtendsBase(name: "alice"), number: 7)
    #expect(c._parent.name == "alice")
    #expect(c.number == 7)
}

@Test func testExtendsForwardsParentPropertyViaDynamicMember() async throws {
    let c = ExtendsChild(ExtendsBase(name: "alice"), number: 7)
    #expect(c.name == "alice")
}

@Test func testExtendsFlatJSONEncode() async throws {
    let c = ExtendsChild(ExtendsBase(name: "alice"), number: 7)
    let data = try JSONEncoder().encode(c)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("\"name\":\"alice\""))
    #expect(json.contains("\"number\":7"))
    #expect(!json.contains("\"_parent\""))
}

@Test func testExtendsFlatJSONDecode() async throws {
    let jsonString = """
        {"name":"alice","number":7}
        """
    let c = try decodeFromJSON(ExtendsChild.self, from: jsonString)
    #expect(c.name == "alice")
    #expect(c.number == 7)
}

@Extends(ExtendsBase.self)
@dynamicMemberLookup
struct ExtendsChildWithOptional {
    var note: String?
}

@Test func testExtendsHandlesOptionalChildField() async throws {
    let jsonString = """
        {"name":"alice"}
        """
    let c = try decodeFromJSON(ExtendsChildWithOptional.self, from: jsonString)
    #expect(c.name == "alice")
    #expect(c.note == nil)
}

@UnionDiscriminator("type")
struct ExtendsDiscBase: Codable {
    @Union("extends_disc", "extends_disc_b") enum Kind {}
    let type: Kind
    var label: String
}

@Extends(ExtendsDiscBase.self)
@dynamicMemberLookup
struct ExtendsDiscChild {
    var payload: Int
}

extension ExtendsDiscChild: TypeDiscriminated {
    typealias DiscriminatorType = ExtendsDiscBase.Kind
    static var discriminatorKey: String { ExtendsDiscBase.discriminatorKey }
}

@Extends(ExtendsDiscBase.self)
@dynamicMemberLookup
struct ExtendsDiscChildB {
    var otherPayload: String
}

extension ExtendsDiscChildB: TypeDiscriminated {
    typealias DiscriminatorType = ExtendsDiscBase.Kind
    static var discriminatorKey: String { ExtendsDiscBase.discriminatorKey }
}

@Union(ExtendsDiscChild.self, ExtendsDiscChildB.self) enum ExtendsDiscUnion {}

// MARK: - Property override (narrowing String → literal union)

struct OverrideBase: Codable, Equatable {
    var kind: String
    var name: String
}

@Extends(OverrideBase.self)
@dynamicMemberLookup
struct OverrideChild: Equatable {
    @Union("specific") enum Kind {}
    var kind: Kind
    var payload: Int
}

@Test func testOverrideChildValueWinsOnEncode() async throws {
    let c = OverrideChild(
        OverrideBase(kind: "wrong", name: "alice"),
        kind: .specific,
        payload: 7
    )
    let data = try JSONEncoder().encode(c)
    let json = String(data: data, encoding: .utf8)!
    // Parent's "wrong" should be overwritten by child's "specific"
    let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(decoded["kind"] as? String == "specific")
    #expect(decoded["name"] as? String == "alice")
    #expect(decoded["payload"] as? Int == 7)
    // Sanity: no nested _parent key
    #expect(!json.contains("\"_parent\""))
}

@Test func testOverrideDecodeEnforcesChildConstraint() async throws {
    // Valid literal value
    let validJSON = """
        {"kind":"specific","name":"alice","payload":7}
        """
    let c = try decodeFromJSON(OverrideChild.self, from: validJSON)
    #expect(c.name == "alice")
    #expect(c.payload == 7)

    // Invalid literal — parent decodes as String fine, but child's literal enum rejects it.
    let invalidJSON = """
        {"kind":"other","name":"alice","payload":7}
        """
    #expect(throws: (any Error).self) {
        _ = try decodeFromJSON(OverrideChild.self, from: invalidJSON)
    }
}

@Test func testOverrideDynamicMemberResolvesToChild() async throws {
    let c = OverrideChild(
        OverrideBase(kind: "wrong", name: "alice"),
        kind: .specific,
        payload: 7
    )
    // Child's stored property shadows parent's via direct member access.
    #expect(c.kind == .specific)
    // Parent value remains accessible via _parent.
    #expect(c._parent.kind == "wrong")
}

@Test func testExtendsInDiscriminatedUnionRoundtrip() async throws {
    let valueA = ExtendsDiscChild(
        ExtendsDiscBase(type: .extends_disc, label: "hello"),
        payload: 42
    )
    let wrappedA = ExtendsDiscUnion.extendsDiscChild(valueA)

    let dataA = try JSONEncoder().encode(wrappedA)
    let decodedA = try JSONDecoder().decode(ExtendsDiscUnion.self, from: dataA)

    switch decodedA {
    case .extendsDiscChild(let v):
        #expect(v.label == "hello")
        #expect(v.payload == 42)
    case .extendsDiscChildB:
        Issue.record("Expected .extendsDiscChild, got .extendsDiscChildB")
    }

    let valueB = ExtendsDiscChildB(
        ExtendsDiscBase(type: .extends_disc_b, label: "world"),
        otherPayload: "xyz"
    )
    let wrappedB = ExtendsDiscUnion.extendsDiscChildB(valueB)

    let dataB = try JSONEncoder().encode(wrappedB)
    let decodedB = try JSONDecoder().decode(ExtendsDiscUnion.self, from: dataB)

    switch decodedB {
    case .extendsDiscChildB(let v):
        #expect(v.label == "world")
        #expect(v.otherPayload == "xyz")
    case .extendsDiscChild:
        Issue.record("Expected .extendsDiscChildB, got .extendsDiscChild")
    }
}
