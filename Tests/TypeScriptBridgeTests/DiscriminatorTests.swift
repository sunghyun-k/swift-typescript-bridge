import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Discriminator Test Types

@UnionDiscriminator("type")
struct DiscClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

@UnionDiscriminator("type")
struct DiscKeyboardEvent: Codable {
    @Union("keydown", "keyup") enum EventType {}
    let type: EventType
    var key: String
}

@Union(DiscClickEvent.self, DiscKeyboardEvent.self) enum DiscUIEvent {}

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

// MARK: - Discriminator-Based Decoding Tests

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
    let clickUIEvent = try decoder.decode(DiscUIEvent.self, from: clickData)

    switch clickUIEvent {
    case .DiscClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["100", "200"])
    case .DiscKeyboardEvent:
        Issue.record("Should decode as ClickEvent based on discriminator")
    }

    // Decode KeyboardEvent via discriminator
    let keyboardData = keyboardJSON.data(using: .utf8)!
    let keyboardUIEvent = try decoder.decode(DiscUIEvent.self, from: keyboardData)

    switch keyboardUIEvent {
    case .DiscKeyboardEvent(let event):
        #expect(event.type.rawValue == "keydown")
        #expect(event.key == "Enter")
    case .DiscClickEvent:
        Issue.record("Should decode as KeyboardEvent based on discriminator")
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
        Issue.record("Should decode as MediaEvent")
    }

    // TextEvent uses "format" as discriminator
    let textData = textJSON.data(using: .utf8)!
    let textContent = try decoder.decode(ContentEvent.self, from: textData)

    switch textContent {
    case .TextEvent(let event):
        #expect(event.format.rawValue == "markdown")
    case .MediaEvent:
        Issue.record("Should decode as TextEvent")
    }
}

@Test func testTypeDiscriminatedProtocol() async throws {
    // Verify that TypeDiscriminator macro generates correct protocol conformance
    #expect(DiscClickEvent.discriminatorKey == "type")
    #expect(DiscClickEvent.DiscriminatorType.self == DiscClickEvent.EventType.self)

    #expect(DiscKeyboardEvent.discriminatorKey == "type")
    #expect(DiscKeyboardEvent.DiscriminatorType.self == DiscKeyboardEvent.EventType.self)

    #expect(MediaEvent.discriminatorKey == "type")
    #expect(MediaEvent.DiscriminatorType.self == MediaEvent.MediaType.self)

    #expect(TextEvent.discriminatorKey == "format")
    #expect(TextEvent.DiscriminatorType.self == TextEvent.Format.self)
}

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
        Issue.record("Expected MediaEvent")
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
        Issue.record("Expected TextEvent")
    }
}

// MARK: - Discriminator Validation Tests

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
        _ = try decoder.decode(DiscUIEvent.self, from: invalidClickData)
        Issue.record("Should have thrown an error for invalid field type")
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
        _ = try decoder.decode(DiscUIEvent.self, from: invalidKeyboardData)
        Issue.record("Should have thrown an error for invalid field type")
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
        _ = try decoder.decode(DiscUIEvent.self, from: data)
        Issue.record("Should have thrown an error for missing required field")
    } catch {
        // Expected - coordinates field is missing
        #expect(error is DecodingError, "Should be a DecodingError")
    }
}
