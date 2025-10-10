import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Basic Test Types

@UnionDiscriminator("type")
struct BasicClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

@UnionDiscriminator("type")
struct BasicKeyboardEvent: Codable {
    @Union("keydown", "keyup") enum EventType {}
    let type: EventType
    var key: String
}

@Union(BasicClickEvent.self, BasicKeyboardEvent.self) enum BasicUIEvent {}

// MARK: - Basic Union Tests

@Test func testLiteralUnionMacro() async throws {
    let clickEvent = BasicClickEvent(type: .click, coordinates: ["100", "200"])

    let encoder = JSONEncoder()
    let data = try encoder.encode(clickEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(BasicClickEvent.self, from: data)

    #expect(decodedEvent.coordinates == ["100", "200"])
}

@Test func testTypeUnionMacro() async throws {
    let clickEvent = BasicClickEvent(type: .click, coordinates: ["100", "200"])
    let uiEvent = BasicUIEvent.BasicClickEvent(clickEvent)

    let data = try encodeToJSON(uiEvent)
    let decodedEvent = try decodeFromJSON(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .BasicClickEvent(let event):
        #expect(event.coordinates == ["100", "200"])
    case .BasicKeyboardEvent:
        Issue.record("Expected BasicClickEvent, got BasicKeyboardEvent")
    }
}

@Test func testKeyboardEvent() async throws {
    let keyboardEvent = BasicKeyboardEvent(type: .keydown, key: "Enter")
    let uiEvent = BasicUIEvent.BasicKeyboardEvent(keyboardEvent)

    let data = try encodeToJSON(uiEvent)
    let decodedEvent = try decodeFromJSON(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .BasicKeyboardEvent(let event):
        #expect(event.key == "Enter")
    case .BasicClickEvent:
        Issue.record("Expected BasicKeyboardEvent, got BasicClickEvent")
    }
}

@Test func testHardcodedClickEventJSON() async throws {
    let jsonString = """
        {
            "type": "click",
            "coordinates": ["150", "300"]
        }
        """

    let clickEvent = try decodeFromJSON(BasicClickEvent.self, from: jsonString)

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

    // Click Event 테스트
    let clickUIEvent = try decodeFromJSON(BasicUIEvent.self, from: clickEventJSON)

    switch clickUIEvent {
    case .BasicClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["100", "200"])
    case .BasicKeyboardEvent:
        Issue.record("Expected BasicClickEvent, got BasicKeyboardEvent")
    }

    // Keyboard Event 테스트
    let keyboardUIEvent = try decodeFromJSON(BasicUIEvent.self, from: keyboardEventJSON)

    switch keyboardUIEvent {
    case .BasicKeyboardEvent(let event):
        #expect(event.type.rawValue == "keyup")
        #expect(event.key == "Escape")
    case .BasicClickEvent:
        Issue.record("Expected BasicKeyboardEvent, got BasicClickEvent")
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

    // Should decode as SimpleA (first match)
    let unionA = try decodeFromJSON(SimpleUnion.self, from: simpleAJSON)

    switch unionA {
    case .SimpleA(let event):
        #expect(event.value == "test")
    case .SimpleB:
        Issue.record("Should decode as SimpleA (first matching type)")
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

    let unionB = try decodeFromJSON(SimpleUnion.self, from: simpleBJSON)

    // Will decode as SimpleA due to first-match behavior
    switch unionB {
    case .SimpleA(let event):
        #expect(event.value == "test")
    case .SimpleB:
        // SimpleB would only be selected if SimpleA failed to decode
        Issue.record("Decoded as SimpleB (unexpected but valid)")
    }
}
