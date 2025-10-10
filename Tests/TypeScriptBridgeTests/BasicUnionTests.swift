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

    let encoder = JSONEncoder()
    let data = try encoder.encode(uiEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .BasicClickEvent(let event):
        #expect(event.coordinates == ["100", "200"])
    case .BasicKeyboardEvent:
        #expect(Bool(false), "Expected click event")
    }
}

@Test func testKeyboardEvent() async throws {
    let keyboardEvent = BasicKeyboardEvent(type: .keydown, key: "Enter")
    let uiEvent = BasicUIEvent.BasicKeyboardEvent(keyboardEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(uiEvent)

    let decoder = JSONDecoder()
    let decodedEvent = try decoder.decode(BasicUIEvent.self, from: data)

    switch decodedEvent {
    case .BasicKeyboardEvent(let event):
        #expect(event.key == "Enter")
    case .BasicClickEvent:
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
    let clickEvent = try decoder.decode(BasicClickEvent.self, from: data)

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
    case .BasicClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["100", "200"])
    case .BasicKeyboardEvent:
        #expect(Bool(false), "Expected click event")
    }

    // Keyboard Event 테스트
    let keyboardData = keyboardEventJSON.data(using: .utf8)!
    let keyboardUIEvent = try decoder.decode(BasicUIEvent.self, from: keyboardData)

    switch keyboardUIEvent {
    case .BasicKeyboardEvent(let event):
        #expect(event.type.rawValue == "keyup")
        #expect(event.key == "Escape")
    case .BasicClickEvent:
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
