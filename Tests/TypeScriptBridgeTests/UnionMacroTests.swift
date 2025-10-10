import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Basic Test Types

@UnionDiscriminator("type")
struct ClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

@UnionDiscriminator("type")
struct KeyboardEvent: Codable {
    @Union("keydown", "keyup") enum EventType {}
    let type: EventType
    var key: String
}

@Union(ClickEvent.self, KeyboardEvent.self) enum BasicUIEvent {}

// MARK: - Union Macro Basic Tests

@Test func testLiteralUnionMacro() async throws {
    let clickEvent = ClickEvent(type: .click, coordinates: ["100", "200"])

    let encoder = JSONEncoder()
    let data = try encoder.encode(clickEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(ClickEvent.self, from: data)

    #expect(decodedEvent.coordinates == ["100", "200"])
}

@Test func testTypeUnionMacro() async throws {
    let clickEvent = ClickEvent(type: .click, coordinates: ["100", "200"])
    let uiEvent = BasicUIEvent.ClickEvent(clickEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(uiEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .ClickEvent(let event):
        #expect(event.coordinates == ["100", "200"])
    case .KeyboardEvent:
        #expect(Bool(false), "Expected click event")
    }
}

@Test func testKeyboardEvent() async throws {
    let keyboardEvent = KeyboardEvent(type: .keydown, key: "Enter")
    let uiEvent = BasicUIEvent.KeyboardEvent(keyboardEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(uiEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .KeyboardEvent(let event):
        #expect(event.key == "Enter")
    case .ClickEvent:
        #expect(Bool(false), "Expected keyboard event")
    }
}

@Test func testHardcodedClickEventJSON() async throws {
    let jsonString = """
        {
            "type": "click",
            "coordinates": ["150", "300"]
        }
        """

    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let clickEvent = try decoder.decode(ClickEvent.self, from: data)

    #expect(clickEvent.type.rawValue == "click")
    #expect(clickEvent.coordinates == ["150", "300"])
}

@Test func testHardcodedUIEventJSON() async throws {
    let clickEventJSON = """
        {
            "type": "click",
            "coordinates": ["100", "200"]
        }
        """

    let keyboardEventJSON = """
        {
            "type": "keyup",
            "key": "Escape"
        }
        """

    let decoder = JSONDecoder()

    // Click Event 테스트
    let clickData = clickEventJSON.data(using: .utf8)!
    let clickUIEvent = try decoder.decode(BasicUIEvent.self, from: clickData)

    switch clickUIEvent {
    case .ClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["100", "200"])
    case .KeyboardEvent:
        #expect(Bool(false), "Expected click event")
    }

    // Keyboard Event 테스트
    let keyboardData = keyboardEventJSON.data(using: .utf8)!
    let keyboardUIEvent = try decoder.decode(BasicUIEvent.self, from: keyboardData)

    switch keyboardUIEvent {
    case .KeyboardEvent(let event):
        #expect(event.type.rawValue == "keyup")
        #expect(event.key == "Escape")
    case .ClickEvent:
        #expect(Bool(false), "Expected keyboard event")
    }
}

// MARK: - Multiple Union Values Tests

struct MultiOptionEvent: Codable {
    @Union("start", "pause", "stop", "reset", "configure") enum Action {}
    let action: Action
    let timestamp: TimeInterval
}

@Test func testMultipleLiteralUnionValues() async throws {
    let actions: [MultiOptionEvent.Action] = [.start, .pause, .stop, .reset, .configure]

    for action in actions {
        let event = MultiOptionEvent(action: action, timestamp: Date().timeIntervalSince1970)

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MultiOptionEvent.self, from: data)

        #expect(decoded.action.rawValue == action.rawValue)
        #expect(decoded.timestamp == event.timestamp)
    }
}

struct A: Codable {}

// MARK: - Numeric and Boolean Literal Union Tests

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

@Test func testIntLiteralUnion() async throws {
    let response = HTTPResponse(statusCode: .`200`, message: "Success")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(response)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(HTTPResponse.self, from: data)
    
    #expect(decoded.statusCode.rawValue == 200)
    #expect(decoded.message == "Success")
}

@Test func testDoubleLiteralUnion() async throws {
    let config = GameConfig(difficulty: .`1.5`, playerName: "Alice")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GameConfig.self, from: data)
    
    #expect(decoded.difficulty.rawValue == 1.5)
    #expect(decoded.playerName == "Alice")
}

@Test func testBoolLiteralUnion() async throws {
    let flag = FeatureFlag(enabled: .`true`, feature: "newUI")
    
    let encoder = JSONEncoder()
    let data = try encoder.encode(flag)
    
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(FeatureFlag.self, from: data)
    
    #expect(decoded.enabled.rawValue == true)
    #expect(decoded.feature == "newUI")
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

// MARK: - Enum with Associated Values in Union

@UnionDiscriminator("type")
struct MediaEvent: Codable {
    @Union("image", "video", "audio", "document") enum MediaType {}
    let type: MediaType
    let url: String
    let metadata: [String: String]?
}

@UnionDiscriminator("format")
struct TextEvent: Codable {
    @Union("plain", "markdown", "html") enum Format {}
    let format: Format
    let content: String
    let length: Int
}

@Union(MediaEvent.self, TextEvent.self) enum ContentEvent {}

@Test func testContentEventWithMetadata() async throws {
    let mediaEvent = MediaEvent(
        type: .video,
        url: "https://example.com/video.mp4",
        metadata: ["duration": "120", "quality": "1080p"]
    )

    let contentEvent = ContentEvent.MediaEvent(mediaEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(contentEvent)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ContentEvent.self, from: data)

    switch decoded {
    case .MediaEvent(let event):
        #expect(event.type.rawValue == "video")
        #expect(event.url == "https://example.com/video.mp4")
        #expect(event.metadata?["duration"] == "120")
        #expect(event.metadata?["quality"] == "1080p")
    case .TextEvent:
        #expect(Bool(false), "Expected MediaEvent")
    }
}

@Test func testTextEventWithoutMetadata() async throws {
    let textEvent = TextEvent(
        format: .markdown,
        content: "# 제목\n\n이것은 **마크다운** 텍스트입니다.",
        length: 25
    )

    let contentEvent = ContentEvent.TextEvent(textEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(contentEvent)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ContentEvent.self, from: data)

    switch decoded {
    case .TextEvent(let event):
        #expect(event.format.rawValue == "markdown")
        #expect(event.content == "# 제목\n\n이것은 **마크다운** 텍스트입니다.")
        #expect(event.length == 25)
    case .MediaEvent:
        #expect(Bool(false), "Expected TextEvent")
    }
}

// MARK: - Discriminator-specific Tests

@Test func testDiscriminatorBasedDecoding() async throws {
    // Test that discriminator-based decoding works correctly
    let clickJSON = """
        {
            "type": "click",
            "coordinates": ["100", "200"]
        }
        """
    
    let keyboardJSON = """
        {
            "type": "keydown",
            "key": "Enter"
        }
        """
    
    let decoder = JSONDecoder()
    
    // Decode ClickEvent via discriminator
    let clickData = clickJSON.data(using: .utf8)!
    let clickUIEvent = try decoder.decode(BasicUIEvent.self, from: clickData)
    
    switch clickUIEvent {
    case .ClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["100", "200"])
    case .KeyboardEvent:
        #expect(Bool(false), "Should decode as ClickEvent based on discriminator")
    }
    
    // Decode KeyboardEvent via discriminator
    let keyboardData = keyboardJSON.data(using: .utf8)!
    let keyboardUIEvent = try decoder.decode(BasicUIEvent.self, from: keyboardData)
    
    switch keyboardUIEvent {
    case .KeyboardEvent(let event):
        #expect(event.type.rawValue == "keydown")
        #expect(event.key == "Enter")
    case .ClickEvent:
        #expect(Bool(false), "Should decode as KeyboardEvent based on discriminator")
    }
}

@Test func testDifferentDiscriminatorFields() async throws {
    // Test that different discriminator fields work correctly
    let mediaJSON = """
        {
            "type": "video",
            "url": "https://example.com/video.mp4",
            "metadata": {"duration": "120"}
        }
        """
    
    let textJSON = """
        {
            "format": "markdown",
            "content": "Hello",
            "length": 5
        }
        """
    
    let decoder = JSONDecoder()
    
    // MediaEvent uses "type" as discriminator
    let mediaData = mediaJSON.data(using: .utf8)!
    let mediaContent = try decoder.decode(ContentEvent.self, from: mediaData)
    
    switch mediaContent {
    case .MediaEvent(let event):
        #expect(event.type.rawValue == "video")
    case .TextEvent:
        #expect(Bool(false), "Should decode as MediaEvent")
    }
    
    // TextEvent uses "format" as discriminator
    let textData = textJSON.data(using: .utf8)!
    let textContent = try decoder.decode(ContentEvent.self, from: textData)
    
    switch textContent {
    case .TextEvent(let event):
        #expect(event.format.rawValue == "markdown")
    case .MediaEvent:
        #expect(Bool(false), "Should decode as TextEvent")
    }
}

@Test func testTypeDiscriminatedProtocol() async throws {
    // Verify that TypeDiscriminator macro generates correct protocol conformance
    #expect(ClickEvent.discriminatorKey == "type")
    #expect(ClickEvent.discriminatorValues == ["click"])
    
    #expect(KeyboardEvent.discriminatorKey == "type")
    #expect(KeyboardEvent.discriminatorValues.contains("keydown"))
    #expect(KeyboardEvent.discriminatorValues.contains("keyup"))
    #expect(KeyboardEvent.discriminatorValues.count == 2)
    
    #expect(MediaEvent.discriminatorKey == "type")
    #expect(MediaEvent.discriminatorValues == ["image", "video", "audio", "document"])
    
    #expect(TextEvent.discriminatorKey == "format")
    #expect(TextEvent.discriminatorValues == ["plain", "markdown", "html"])
}

@Test func testDiscriminatorMatchButInvalidFields() async throws {
    // Test that when discriminator matches but other fields are invalid types,
    // decoding fails with a proper error (not silently succeeding)
    
    // ClickEvent expects coordinates as [String], but we provide a number
    let invalidClickJSON = """
        {
            "type": "click",
            "coordinates": 123
        }
        """
    
    let decoder = JSONDecoder()
    let invalidClickData = invalidClickJSON.data(using: .utf8)!
    
    // Should throw an error, not succeed
    do {
        _ = try decoder.decode(BasicUIEvent.self, from: invalidClickData)
        #expect(Bool(false), "Should have thrown an error for invalid field type")
    } catch {
        // Expected - should fail to decode
        #expect(error is DecodingError, "Should be a DecodingError")
    }
    
    // KeyboardEvent expects KeyboardEvent fields, but we provide ClickEvent fields
    let invalidKeyboardJSON = """
        {
            "type": "keydown",
            "coordinates": ["100", "200"]
        }
        """
    
    let invalidKeyboardData = invalidKeyboardJSON.data(using: .utf8)!
    
    do {
        _ = try decoder.decode(BasicUIEvent.self, from: invalidKeyboardData)
        #expect(Bool(false), "Should have thrown an error for invalid field type")
    } catch {
        // Expected - should fail to decode
        #expect(error is DecodingError, "Should be a DecodingError")
    }
}

@Test func testDiscriminatorMatchButMissingRequiredFields() async throws {
    // Test that when discriminator matches but required fields are missing,
    // decoding fails properly
    
    let missingFieldsJSON = """
        {
            "type": "click"
        }
        """
    
    let decoder = JSONDecoder()
    let data = missingFieldsJSON.data(using: .utf8)!
    
    do {
        _ = try decoder.decode(BasicUIEvent.self, from: data)
        #expect(Bool(false), "Should have thrown an error for missing required field")
    } catch {
        // Expected - coordinates field is missing
        #expect(error is DecodingError, "Should be a DecodingError")
    }
}

// MARK: - Non-Discriminated Union Tests (Backward Compatibility)

struct SimpleA: Codable {
    let value: String
}

struct SimpleB: Codable {
    let value: String
    let extra: Int
}

@Union(SimpleA.self, SimpleB.self) enum SimpleUnion {}

@Test func testNonDiscriminatedUnionFallback() async throws {
    // Test that unions without discriminators still work (backward compatibility)
    // Note: Without discriminators, the first matching type will be selected.
    // This is a limitation of non-discriminated unions.
    let simpleAJSON = """
        {
            "value": "test"
        }
        """
    
    let decoder = JSONDecoder()
    
    // Should decode as SimpleA (first match)
    let dataA = simpleAJSON.data(using: .utf8)!
    let unionA = try decoder.decode(SimpleUnion.self, from: dataA)
    
    switch unionA {
    case .SimpleA(let event):
        #expect(event.value == "test")
    case .SimpleB:
        #expect(Bool(false), "Should decode as SimpleA")
    }
    
    // Note: SimpleB with extra fields will still decode as SimpleA because
    // Codable ignores extra fields by default. This is why discriminators are recommended.
    // Test that it at least decodes successfully (even if as SimpleA)
    let simpleBJSON = """
        {
            "value": "test",
            "extra": 42
        }
        """
    
    let dataB = simpleBJSON.data(using: .utf8)!
    let unionB = try decoder.decode(SimpleUnion.self, from: dataB)
    
    // Will decode as SimpleA due to first-match behavior
    switch unionB {
    case .SimpleA(let event):
        #expect(event.value == "test")
    case .SimpleB:
        // SimpleB would only be selected if SimpleA failed to decode
        #expect(Bool(false), "Decoded as SimpleB (unexpected but valid)")
    }
}
