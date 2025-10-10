import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Validation Test Types

@UnionDiscriminator("type")
struct ValidatedClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

@UnionDiscriminator("type")
struct ValidatedKeyboardEvent: Codable {
    @Union("keydown", "keyup") enum EventType {}
    let type: EventType
    var key: String
}

struct StrictEvent: Codable {
    @Union("allowed", "permitted", "valid") enum Status {}
    let status: Status
    let message: String
}

@Union(ValidatedClickEvent.self, ValidatedKeyboardEvent.self) enum ValidatedUIEvent {}

// MARK: - Type Validation Tests

@Test func testInvalidLiteralUnionValueRejection() async throws {
    let invalidJSON = """
        {
            "type": "invalid_type",
            "coordinates": ["100", "200"]
        }
        """

    // 잘못된 type 값은 디코딩 실패해야 함
    try await expectDecodingFailure(ValidatedClickEvent.self, from: invalidJSON)
}

@Test func testValidLiteralUnionValueAcceptance() async throws {
    let validJSON = """
        {
            "type": "click",
            "coordinates": ["100", "200"]
        }
        """

    // 올바른 type 값은 성공해야 함
    let clickEvent = try decodeFromJSON(ValidatedClickEvent.self, from: validJSON)
    #expect(clickEvent.type.rawValue == "click")
    #expect(clickEvent.coordinates == ["100", "200"])
}

@Test func testKeyboardEventTypeValidation() async throws {
    let validKeydownJSON = """
        {
            "type": "keydown",
            "key": "Enter"
        }
        """

    let validKeyupJSON = """
        {
            "type": "keyup",
            "key": "Escape"
        }
        """

    let invalidJSON = """
        {
            "type": "invalid_key_type",
            "key": "Enter"
        }
        """

    // 유효한 keydown
    let keydownEvent = try decodeFromJSON(ValidatedKeyboardEvent.self, from: validKeydownJSON)
    #expect(keydownEvent.type.rawValue == "keydown")
    #expect(keydownEvent.key == "Enter")

    // 유효한 keyup
    let keyupEvent = try decodeFromJSON(ValidatedKeyboardEvent.self, from: validKeyupJSON)
    #expect(keyupEvent.type.rawValue == "keyup")
    #expect(keyupEvent.key == "Escape")

    // 무효한 type
    try await expectDecodingFailure(ValidatedKeyboardEvent.self, from: invalidJSON)
}

@Test func testTypeUnionValidation() async throws {
    // 유효한 클릭 이벤트
    let validClickJSON = """
        {
            "type": "click",
            "coordinates": ["50", "75"]
        }
        """

    // 유효한 키보드 이벤트
    let validKeyboardJSON = """
        {
            "type": "keydown",
            "key": "Space"
        }
        """

    // 구조는 맞지만 잘못된 타입 값
    let invalidTypeJSON = """
        {
            "type": "invalid",
            "coordinates": ["50", "75"]
        }
        """

    // 완전히 잘못된 구조
    let invalidStructureJSON = """
        {
            "wrongField": "value"
        }
        """

    // 유효한 클릭 이벤트 테스트
    let clickUIEvent = try decodeFromJSON(ValidatedUIEvent.self, from: validClickJSON)

    switch clickUIEvent {
    case .ValidatedClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["50", "75"])
    case .ValidatedKeyboardEvent:
        Issue.record("Expected ValidatedClickEvent, got ValidatedKeyboardEvent")
    }

    // 유효한 키보드 이벤트 테스트
    let keyboardUIEvent = try decodeFromJSON(ValidatedUIEvent.self, from: validKeyboardJSON)

    switch keyboardUIEvent {
    case .ValidatedKeyboardEvent(let event):
        #expect(event.type.rawValue == "keydown")
        #expect(event.key == "Space")
    case .ValidatedClickEvent:
        Issue.record("Expected ValidatedKeyboardEvent, got ValidatedClickEvent")
    }

    // 잘못된 타입 값 테스트
    try await expectDecodingFailure(ValidatedUIEvent.self, from: invalidTypeJSON)

    // 잘못된 구조 테스트
    try await expectDecodingFailure(ValidatedUIEvent.self, from: invalidStructureJSON)
}

@Test func testStrictValidationWithMultipleLiterals() async throws {
    let testCases: [(String, Bool)] = [
        ("allowed", true),
        ("permitted", true),
        ("valid", true),
        ("invalid", false),
        ("forbidden", false),
        ("", false),
        ("ALLOWED", false),  // 대소문자 구분
        ("allowed ", false),  // 공백 포함
    ]

    for (status, shouldSucceed) in testCases {
        let json = """
            {
                "status": "\(status)",
                "message": "Test message"
            }
            """

        if shouldSucceed {
            let event = try decodeFromJSON(StrictEvent.self, from: json)
            #expect(event.status.rawValue == status)
            #expect(event.message == "Test message")
        } else {
            try await expectDecodingFailure(StrictEvent.self, from: json)
        }
    }
}

@Test func testCaseSensitiveValidation() async throws {
    // 대소문자가 정확히 일치해야 함을 테스트
    let correctCaseJSON = """
        {
            "status": "allowed",
            "message": "Correct case"
        }
        """

    let incorrectCaseJSON = """
        {
            "status": "Allowed",
            "message": "Incorrect case"
        }
        """

    // 올바른 대소문자
    let correctEvent = try decodeFromJSON(StrictEvent.self, from: correctCaseJSON)
    #expect(correctEvent.status.rawValue == "allowed")

    // 잘못된 대소문자
    try await expectDecodingFailure(StrictEvent.self, from: incorrectCaseJSON)
}
