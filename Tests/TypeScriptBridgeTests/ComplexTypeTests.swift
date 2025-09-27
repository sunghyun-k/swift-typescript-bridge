import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Complex Types for Testing

// Nested structures
struct UserProfile: Codable {
    @Union("basic", "premium", "enterprise") enum AccountType {}

    let id: String
    let name: String
    let accountType: AccountType
    let settings: UserSettings
}

struct UserSettings: Codable {
    @Union("dark", "light", "auto") enum Theme {}

    let theme: Theme
    let notifications: Bool
    let language: String
}

// Generic data wrapper
struct APIResponse<T: Codable>: Codable {
    @Union("success", "error", "loading") enum Status {}

    let status: Status
    let data: T?
    let message: String?
    let timestamp: Date
}

// Complex nested union with multiple levels
struct WebSocketMessage: Codable {
    let id: String
    let timestamp: Date
    let payload: MessagePayload
}

@Union(ChatMessage.self, SystemNotification.self, UserActivity.self, ErrorReport.self) enum MessagePayload {}

struct ChatMessage: Codable {
    @Union("text", "image", "file", "emoji") enum MessageType {}

    let type: MessageType
    let content: String
    let senderId: String
    let channelId: String
}

struct SystemNotification: Codable {
    @Union("info", "warning", "critical") enum Priority {}

    let priority: Priority
    let title: String
    let body: String
    let actionRequired: Bool
}

struct UserActivity: Codable {
    @Union("login", "logout", "page_view", "button_click", "form_submit") enum ActivityType {}

    let type: ActivityType
    let userId: String
    let metadata: [String: String]
}

struct ErrorReport: Codable {
    @Union("client", "server", "network", "validation") enum ErrorCategory {}

    let category: ErrorCategory
    let code: Int
    let message: String
    let stackTrace: String?
    let userAgent: String?
}

// Multi-level nested unions
@Union(DatabaseEvent.self, NetworkEvent.self, InteractionEvent.self) enum ComplexSystemEvent {}

struct DatabaseEvent: Codable {
    @Union("insert", "update", "delete", "query") enum Operation {}

    let operation: Operation
    let table: String
    let recordId: String?
    let affectedRows: Int
}

struct NetworkEvent: Codable {
    @Union("request", "response", "timeout", "error") enum EventType {}

    let type: EventType
    let url: String
    let method: String
    let statusCode: Int?
    let duration: TimeInterval?
}

struct ViewportSize: Codable {
    let width: Double
    let height: Double
}

struct InteractionEvent: Codable {
    @Union("click", "scroll", "resize", "focus", "blur") enum InteractionType {}

    let type: InteractionType
    let elementId: String?
    let coordinates: [Double]?
    let viewport: ViewportSize?
}

// MARK: - Complex Type Tests

@Test func testNestedStructureWithUnions() async throws {
    let settings = UserSettings(theme: .dark, notifications: true, language: "ko")
    let profile = UserProfile(
        id: "user123",
        name: "swiftlang",
        accountType: .premium,
        settings: settings
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(profile)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(UserProfile.self, from: data)

    #expect(decoded.id == "user123")
    #expect(decoded.name == "swiftlang")
    #expect(decoded.accountType.rawValue == "premium")
    #expect(decoded.settings.theme.rawValue == "dark")
    #expect(decoded.settings.notifications == true)
    #expect(decoded.settings.language == "ko")
}

@Test func testGenericAPIResponseWithUnion() async throws {
    let apiResponse = APIResponse<UserProfile>(
        status: .success,
        data: UserProfile(
            id: "test123",
            name: "Test User",
            accountType: .basic,
            settings: UserSettings(theme: .light, notifications: false, language: "en")
        ),
        message: "User profile retrieved successfully",
        timestamp: Date()
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(apiResponse)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(APIResponse<UserProfile>.self, from: data)

    #expect(decoded.status.rawValue == "success")
    #expect(decoded.data?.name == "Test User")
    #expect(decoded.message == "User profile retrieved successfully")
}

@Test func testComplexWebSocketMessage() async throws {
    let chatMessage = ChatMessage(
        type: .text,
        content: "안녕하세요!",
        senderId: "user456",
        channelId: "general"
    )

    let wsMessage = WebSocketMessage(
        id: "msg789",
        timestamp: Date(),
        payload: .ChatMessage(chatMessage)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(wsMessage)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(WebSocketMessage.self, from: data)

    #expect(decoded.id == "msg789")

    switch decoded.payload {
    case .ChatMessage(let message):
        #expect(message.type.rawValue == "text")
        #expect(message.content == "안녕하세요!")
        #expect(message.senderId == "user456")
        #expect(message.channelId == "general")
    default:
        #expect(Bool(false), "Expected ChatMessage payload")
    }
}

@Test func testSystemNotificationMessage() async throws {
    let notification = SystemNotification(
        priority: .critical,
        title: "시스템 점검 안내",
        body: "오늘 밤 12시부터 2시간 동안 시스템 점검이 예정되어 있습니다.",
        actionRequired: true
    )

    let wsMessage = WebSocketMessage(
        id: "notif001",
        timestamp: Date(),
        payload: .SystemNotification(notification)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(wsMessage)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(WebSocketMessage.self, from: data)

    switch decoded.payload {
    case .SystemNotification(let notif):
        #expect(notif.priority.rawValue == "critical")
        #expect(notif.title == "시스템 점검 안내")
        #expect(notif.actionRequired == true)
    default:
        #expect(Bool(false), "Expected SystemNotification payload")
    }
}

@Test func testMultiLevelSystemEvent() async throws {
    let dbEvent = DatabaseEvent(
        operation: .insert,
        table: "users",
        recordId: "12345",
        affectedRows: 1
    )

    let systemEvent = ComplexSystemEvent.DatabaseEvent(dbEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(systemEvent)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ComplexSystemEvent.self, from: data)

    switch decoded {
    case .DatabaseEvent(let event):
        #expect(event.operation.rawValue == "insert")
        #expect(event.table == "users")
        #expect(event.recordId == "12345")
        #expect(event.affectedRows == 1)
    default:
        #expect(Bool(false), "Expected DatabaseEvent")
    }
}

@Test func testInteractionEventWithOptionalFields() async throws {
    let interactionEvent = InteractionEvent(
        type: .click,
        elementId: "submit-button",
        coordinates: [100.5, 200.3],
        viewport: ViewportSize(width: 1920, height: 1080)
    )

    let systemEvent = ComplexSystemEvent.InteractionEvent(interactionEvent)

    let encoder = JSONEncoder()
    let data = try encoder.encode(systemEvent)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ComplexSystemEvent.self, from: data)

    switch decoded {
    case .InteractionEvent(let event):
        #expect(event.type.rawValue == "click")
        #expect(event.elementId == "submit-button")
        #expect(event.coordinates?[0] == 100.5)
        #expect(event.coordinates?[1] == 200.3)
        #expect(event.viewport?.width == 1920)
    default:
        #expect(Bool(false), "Expected InteractionEvent")
    }
}

@Test func testErrorReportWithNilValues() async throws {
    let errorReport = ErrorReport(
        category: .network,
        code: 404,
        message: "페이지를 찾을 수 없습니다",
        stackTrace: nil,
        userAgent: "Mozilla/5.0..."
    )

    let wsMessage = WebSocketMessage(
        id: "error001",
        timestamp: Date(),
        payload: .ErrorReport(errorReport)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(wsMessage)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(WebSocketMessage.self, from: data)

    switch decoded.payload {
    case .ErrorReport(let error):
        #expect(error.category.rawValue == "network")
        #expect(error.code == 404)
        #expect(error.message == "페이지를 찾을 수 없습니다")
        #expect(error.stackTrace == nil)
        #expect(error.userAgent == "Mozilla/5.0...")
    default:
        #expect(Bool(false), "Expected ErrorReport payload")
    }
}
