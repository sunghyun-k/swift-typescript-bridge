import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Integration Tests
// This file contains integration tests that verify the overall functionality
// of the Union macro system working together

// MARK: - Test Types for Integration

struct AuthEvent: Codable {
    @Union("login", "logout", "session_expired") enum EventType {}
    let type: EventType
    let userId: String
    let timestamp: Date
}

struct DataEvent: Codable {
    @Union("create", "update", "delete") enum Operation {}
    let operation: Operation
    let entityId: String
    let changes: [String: String]?
}

@Union(AuthEvent.self, DataEvent.self) enum IntegrationSystemEvent {}

// MARK: - Integration Tests

@Test func testEndToEndWorkflow() async throws {
    // Create various events
    let loginEvent = AuthEvent(
        type: .login,
        userId: "user123",
        timestamp: Date()
    )

    let updateEvent = DataEvent(
        operation: .update,
        entityId: "entity456",
        changes: ["name": "New Name", "status": "active"]
    )

    // Package into system events
    let systemEvents: [IntegrationSystemEvent] = [
        .AuthEvent(loginEvent),
        .DataEvent(updateEvent),
    ]

    // Encode all events
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(systemEvents)

    // Decode all events
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedEvents = try decoder.decode([IntegrationSystemEvent].self, from: data)

    #expect(decodedEvents.count == 2)

    // Verify first event
    switch decodedEvents[0] {
    case .AuthEvent(let event):
        #expect(event.type.rawValue == "login")
        #expect(event.userId == "user123")
    case .DataEvent:
        #expect(Bool(false), "Expected AuthEvent")
    }

    // Verify second event
    switch decodedEvents[1] {
    case .DataEvent(let event):
        #expect(event.operation.rawValue == "update")
        #expect(event.entityId == "entity456")
        #expect(event.changes?["name"] == "New Name")
    case .AuthEvent:
        #expect(Bool(false), "Expected DataEvent")
    }
}

@Test func testMixedUnionTypesInteraction() async throws {
    // Test that different union types can coexist without conflicts
    let authEvents = [
        AuthEvent(type: .login, userId: "user1", timestamp: Date()),
        AuthEvent(type: .logout, userId: "user2", timestamp: Date()),
        AuthEvent(type: .session_expired, userId: "user3", timestamp: Date()),
    ]

    let dataEvents = [
        DataEvent(operation: .create, entityId: "entity1", changes: ["name": "New Entity"]),
        DataEvent(operation: .update, entityId: "entity2", changes: ["status": "updated"]),
        DataEvent(operation: .delete, entityId: "entity3", changes: nil),
    ]

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // Test encoding/decoding individual types
    for authEvent in authEvents {
        let data = try encoder.encode(authEvent)
        let decoded = try decoder.decode(AuthEvent.self, from: data)
        #expect(decoded.type.rawValue == authEvent.type.rawValue)
        #expect(decoded.userId == authEvent.userId)
    }

    for dataEvent in dataEvents {
        let data = try encoder.encode(dataEvent)
        let decoded = try decoder.decode(DataEvent.self, from: data)
        #expect(decoded.operation.rawValue == dataEvent.operation.rawValue)
        #expect(decoded.entityId == dataEvent.entityId)
    }
}

@Test func testSystemEventTypeDiscrimination() async throws {
    // Test that the system can correctly discriminate between different event types
    let mixedEvents: [IntegrationSystemEvent] = [
        .AuthEvent(AuthEvent(type: .login, userId: "user1", timestamp: Date())),
        .DataEvent(DataEvent(operation: .create, entityId: "entity1", changes: ["key": "value"])),
        .AuthEvent(AuthEvent(type: .logout, userId: "user2", timestamp: Date())),
        .DataEvent(DataEvent(operation: .delete, entityId: "entity2", changes: nil)),
    ]

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(mixedEvents)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode([IntegrationSystemEvent].self, from: data)

    #expect(decoded.count == 4)

    // Verify correct type discrimination
    let expectedTypes: [(Bool, Bool)] = [(true, false), (false, true), (true, false), (false, true)]

    for (index, (isAuth, isData)) in expectedTypes.enumerated() {
        switch decoded[index] {
        case .AuthEvent:
            #expect(isAuth, "Event \(index) should be AuthEvent")
        case .DataEvent:
            #expect(isData, "Event \(index) should be DataEvent")
        }
    }
}
