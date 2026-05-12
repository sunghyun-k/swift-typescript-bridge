import Foundation
import Testing

@testable import TypeScriptBridge

// MARK: - Nullable string literal union

@Union("pending", "approved", nil) enum NullableStatus {}

@Test func testNullableStringUnionRoundTripsValue() async throws {
    let json = "\"approved\""
    let decoded = try JSONDecoder().decode(NullableStatus.self, from: Data(json.utf8))
    #expect(decoded == .`approved`)

    let encoded = try JSONEncoder().encode(decoded)
    #expect(String(data: encoded, encoding: .utf8) == "\"approved\"")
}

@Test func testNullableStringUnionRoundTripsNull() async throws {
    let json = "null"
    let decoded = try JSONDecoder().decode(NullableStatus.self, from: Data(json.utf8))
    #expect(decoded == .`null`)

    let encoded = try JSONEncoder().encode(decoded)
    #expect(String(data: encoded, encoding: .utf8) == "null")
}

@Test func testNullableStringUnionRejectsUnknownString() async throws {
    let json = "\"unknown\""
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(NullableStatus.self, from: Data(json.utf8))
    }
}

@Test func testNullableStringUnionRawValueIsOptional() async throws {
    let status: NullableStatus = .`approved`
    let rv: String? = status.rawValue
    #expect(rv == "approved")

    let nullStatus: NullableStatus = .`null`
    #expect(nullStatus.rawValue == nil)
}

@Test func testNullableStringUnionRawValueInit() async throws {
    #expect(NullableStatus(rawValue: "pending") == .`pending`)
    #expect(NullableStatus(rawValue: nil) == .`null`)
    #expect(NullableStatus(rawValue: "garbage") == nil)
}

// MARK: - Nullable inside a struct

struct NullableContainer: Codable, Equatable {
    var status: NullableStatus
}

@Test func testNullableInsideStructDecodesNull() async throws {
    let json = #"{"status":null}"#
    let decoded = try JSONDecoder().decode(NullableContainer.self, from: Data(json.utf8))
    #expect(decoded.status == .`null`)
}

@Test func testNullableInsideStructEncodesNull() async throws {
    let value = NullableContainer(status: .`null`)
    let data = try JSONEncoder().encode(value)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("\"status\":null"))
}

// MARK: - Nullable numeric union

@Union(200, 404, 500, nil) enum NullableStatusCode {}

@Test func testNullableNumericUnionDecodesValue() async throws {
    let decoded = try JSONDecoder().decode(NullableStatusCode.self, from: Data("404".utf8))
    #expect(decoded == .`404`)
}

@Test func testNullableNumericUnionDecodesNull() async throws {
    let decoded = try JSONDecoder().decode(NullableStatusCode.self, from: Data("null".utf8))
    #expect(decoded == .`null`)
}

@Test func testNullableNumericUnionRejectsUnknownNumber() async throws {
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(NullableStatusCode.self, from: Data("999".utf8))
    }
}

// MARK: - Nullable mixed-type union

@Union("auto", 100, true, nil) enum NullableConfigValue {}

@Test func testNullableMixedUnionDecodesEachVariant() async throws {
    let cases: [(String, NullableConfigValue)] = [
        ("\"auto\"", .`auto`),
        ("100", .`100`),
        ("true", .`true`),
        ("null", .`null`),
    ]
    for (json, expected) in cases {
        let decoded = try JSONDecoder().decode(NullableConfigValue.self, from: Data(json.utf8))
        #expect(decoded == expected)
        let reencoded = try JSONEncoder().encode(decoded)
        #expect(String(data: reencoded, encoding: .utf8) == json)
    }
}
