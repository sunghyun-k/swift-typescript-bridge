import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Numeric and Boolean Literal Union Test Types

struct HTTPResponse: Codable {
    @Union(200, 404, 500) enum StatusCode {}
    let statusCode: StatusCode
    let message: String
}

struct GameConfig: Codable {
    @Union(1.0, 1.5, 2.0) enum DifficultyMultiplier {}
    let difficulty: DifficultyMultiplier
    let playerName: String
}

struct FeatureFlag: Codable {
    @Union(true, false) enum Enabled {}
    let enabled: Enabled
    let feature: String
}

// MARK: - Integer Literal Union Tests

@Test func testIntLiteralUnion() async throws {
    let response = HTTPResponse(statusCode: .`200`, message: "Success")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(response)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(HTTPResponse.self, from: data)
    
    #expect(decoded.statusCode.rawValue == 200)
    #expect(decoded.message == "Success")
}

@Test func testNumericLiteralUnionJSON() async throws {
    let jsonString = """
        {
            "statusCode": 404,
            "message": "Not Found"
        }
        """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(HTTPResponse.self, from: data)
    
    #expect(response.statusCode.rawValue == 404)
    #expect(response.message == "Not Found")
}

// MARK: - Double Literal Union Tests

@Test func testDoubleLiteralUnion() async throws {
    let config = GameConfig(difficulty: .`1.5`, playerName: "Alice")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GameConfig.self, from: data)
    
    #expect(decoded.difficulty.rawValue == 1.5)
    #expect(decoded.playerName == "Alice")
}

@Test func testDoubleLiteralUnionJSON() async throws {
    let jsonString = """
        {
            "difficulty": 2.0,
            "playerName": "Bob"
        }
        """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let config = try decoder.decode(GameConfig.self, from: data)
    
    #expect(config.difficulty.rawValue == 2.0)
    #expect(config.playerName == "Bob")
}

// MARK: - Boolean Literal Union Tests

@Test func testBoolLiteralUnion() async throws {
    let flag = FeatureFlag(enabled: .`true`, feature: "newUI")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(flag)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(FeatureFlag.self, from: data)
    
    #expect(decoded.enabled.rawValue == true)
    #expect(decoded.feature == "newUI")
}

@Test func testBoolLiteralUnionJSON() async throws {
    let jsonString = """
        {
            "enabled": false,
            "feature": "experimentalMode"
        }
        """
    
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let flag = try decoder.decode(FeatureFlag.self, from: data)
    
    #expect(flag.enabled.rawValue == false)
    #expect(flag.feature == "experimentalMode")
}

// MARK: - Mixed Type Literal Union Tests

struct MixedTypeConfig: Codable {
    @Union("auto", 100, true, 2.5, "manual", false) enum Value {}
    let value: Value
    let name: String
}

@Test func testMixedTypeLiteralUnion() async throws {
    let configs = [
        MixedTypeConfig(value: .`auto`, name: "stringValue"),
        MixedTypeConfig(value: .`100`, name: "intValue"),
        MixedTypeConfig(value: .`true`, name: "boolValue"),
        MixedTypeConfig(value: .`2.5`, name: "doubleValue"),
        MixedTypeConfig(value: .`manual`, name: "anotherString"),
        MixedTypeConfig(value: .`false`, name: "anotherBool")
    ]
    
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    for config in configs {
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(MixedTypeConfig.self, from: data)
        
        // Compare enum cases instead of rawValues for mixed types
        #expect(decoded.value == config.value)
        #expect(decoded.name == config.name)
    }
}

@Test func testMixedTypeLiteralUnionJSON() async throws {
    let testCases: [(json: String, expectedCase: MixedTypeConfig.Value)] = [
        ("""
        {
            "value": "auto",
            "name": "stringValue"
        }
        """, .`auto`),
        ("""
        {
            "value": 100,
            "name": "intValue"
        }
        """, .`100`),
        ("""
        {
            "value": true,
            "name": "boolValue"
        }
        """, .`true`),
        ("""
        {
            "value": 2.5,
            "name": "doubleValue"
        }
        """, .`2.5`),
        ("""
        {
            "value": false,
            "name": "anotherBool"
        }
        """, .`false`)
    ]
    
    let decoder = JSONDecoder()
    
    for testCase in testCases {
        let data = testCase.json.data(using: .utf8)!
        let config = try decoder.decode(MixedTypeConfig.self, from: data)
        
        #expect(config.value == testCase.expectedCase)
    }
}

