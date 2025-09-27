import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Basic Test Types

struct ClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

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

// MARK: - Enum with Associated Values in Union

struct MediaEvent: Codable {
    @Union("image", "video", "audio", "document") enum MediaType {}
    let type: MediaType
    let url: String
    let metadata: [String: String]?
}

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
