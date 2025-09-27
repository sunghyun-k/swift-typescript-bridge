import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Validation Test Types

struct ValidatedClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    var coordinates: [String]
}

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

    let data = invalidJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    // 잘못된 type 값은 디코딩 실패해야 함
    do {
        let _ = try decoder.decode(ValidatedClickEvent.self, from: data)
        #expect(Bool(false), "Should have failed to decode invalid type")
    } catch {
        #expect(error is DecodingError, "Expected DecodingError for invalid type")
    }
}

@Test func testValidLiteralUnionValueAcceptance() async throws {
    let validJSON = """
        {
            "type": "click",
            "coordinates": ["100", "200"]
        }
        """

    let data = validJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    // 올바른 type 값은 성공해야 함
    let clickEvent = try decoder.decode(ValidatedClickEvent.self, from: data)
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

    let decoder = JSONDecoder()

    // 유효한 keydown
    let keydownData = validKeydownJSON.data(using: .utf8)!
    let keydownEvent = try decoder.decode(ValidatedKeyboardEvent.self, from: keydownData)
    #expect(keydownEvent.type.rawValue == "keydown")
    #expect(keydownEvent.key == "Enter")

    // 유효한 keyup
    let keyupData = validKeyupJSON.data(using: .utf8)!
    let keyupEvent = try decoder.decode(ValidatedKeyboardEvent.self, from: keyupData)
    #expect(keyupEvent.type.rawValue == "keyup")
    #expect(keyupEvent.key == "Escape")

    // 무효한 type
    let invalidData = invalidJSON.data(using: .utf8)!
    do {
        let _ = try decoder.decode(ValidatedKeyboardEvent.self, from: invalidData)
        #expect(Bool(false), "Should have failed to decode invalid keyboard type")
    } catch {
        #expect(error is DecodingError, "Expected DecodingError for invalid keyboard type")
    }
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

    let decoder = JSONDecoder()

    // 유효한 클릭 이벤트 테스트
    let clickData = validClickJSON.data(using: .utf8)!
    let clickUIEvent = try decoder.decode(ValidatedUIEvent.self, from: clickData)

    switch clickUIEvent {
    case .ValidatedClickEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.coordinates == ["50", "75"])
    case .ValidatedKeyboardEvent:
        #expect(Bool(false), "Expected ValidatedClickEvent")
    }

    // 유효한 키보드 이벤트 테스트
    let keyboardData = validKeyboardJSON.data(using: .utf8)!
    let keyboardUIEvent = try decoder.decode(ValidatedUIEvent.self, from: keyboardData)

    switch keyboardUIEvent {
    case .ValidatedKeyboardEvent(let event):
        #expect(event.type.rawValue == "keydown")
        #expect(event.key == "Space")
    case .ValidatedClickEvent:
        #expect(Bool(false), "Expected ValidatedKeyboardEvent")
    }

    // 잘못된 타입 값 테스트
    let invalidTypeData = invalidTypeJSON.data(using: .utf8)!
    do {
        let _ = try decoder.decode(ValidatedUIEvent.self, from: invalidTypeData)
        #expect(Bool(false), "Should have failed to decode event with invalid type")
    } catch {
        #expect(error is DecodingError, "Expected DecodingError for invalid type")
    }

    // 잘못된 구조 테스트
    let invalidStructureData = invalidStructureJSON.data(using: .utf8)!
    do {
        let _ = try decoder.decode(ValidatedUIEvent.self, from: invalidStructureData)
        #expect(Bool(false), "Should have failed to decode event with invalid structure")
    } catch {
        #expect(error is DecodingError, "Expected DecodingError for invalid structure")
    }
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

    let decoder = JSONDecoder()

    for (status, shouldSucceed) in testCases {
        let json = """
            {
                "status": "\(status)",
                "message": "Test message"
            }
            """

        let data = json.data(using: .utf8)!

        if shouldSucceed {
            let event = try decoder.decode(StrictEvent.self, from: data)
            #expect(event.status.rawValue == status)
            #expect(event.message == "Test message")
        } else {
            do {
                let _ = try decoder.decode(StrictEvent.self, from: data)
                #expect(Bool(false), "Should have failed to decode status: '\(status)'")
            } catch {
                #expect(error is DecodingError, "Expected DecodingError for status: '\(status)'")
            }
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

    let decoder = JSONDecoder()

    // 올바른 대소문자
    let correctData = correctCaseJSON.data(using: .utf8)!
    let correctEvent = try decoder.decode(StrictEvent.self, from: correctData)
    #expect(correctEvent.status.rawValue == "allowed")

    // 잘못된 대소문자
    let incorrectData = incorrectCaseJSON.data(using: .utf8)!
    do {
        let _ = try decoder.decode(StrictEvent.self, from: incorrectData)
        #expect(Bool(false), "Should have failed with incorrect case")
    } catch {
        #expect(error is DecodingError, "Expected DecodingError for incorrect case")
    }
}
