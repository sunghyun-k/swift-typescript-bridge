import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Test Helpers

/// Helper function to encode and decode a value, verifying round-trip serialization
func roundTrip<T: Codable & Equatable>(
    _ value: T,
    useISO8601: Bool = true
) throws -> T {
    let encoder = JSONEncoder()
    if useISO8601 {
        encoder.dateEncodingStrategy = .iso8601
    }
    let data = try encoder.encode(value)

    let decoder = JSONDecoder()
    if useISO8601 {
        decoder.dateDecodingStrategy = .iso8601
    }
    return try decoder.decode(T.self, from: data)
}

/// Helper function to encode a value and return JSON data
func encodeToJSON<T: Codable>(
    _ value: T,
    dateStrategy: JSONEncoder.DateEncodingStrategy = .iso8601
) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = dateStrategy
    return try encoder.encode(value)
}

/// Helper function to decode JSON data to a value
func decodeFromJSON<T: Codable>(
    _ type: T.Type,
    from data: Data,
    dateStrategy: JSONDecoder.DateDecodingStrategy = .iso8601
) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateStrategy
    return try decoder.decode(type, from: data)
}

/// Helper function to decode JSON string to a value
func decodeFromJSON<T: Codable>(
    _ type: T.Type,
    from jsonString: String,
    dateStrategy: JSONDecoder.DateDecodingStrategy = .iso8601
) throws -> T {
    guard let data = jsonString.data(using: .utf8) else {
        throw TestError.invalidJSONString
    }
    return try decodeFromJSON(type, from: data, dateStrategy: dateStrategy)
}

/// Helper to expect decoding failure
func expectDecodingFailure<T: Codable>(
    _ type: T.Type,
    from jsonString: String,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    guard let data = jsonString.data(using: .utf8) else {
        Issue.record(TestError.invalidJSONString, sourceLocation: sourceLocation)
        return
    }

    do {
        _ = try decodeFromJSON(type, from: data)
        Issue.record(TestError.unexpectedSuccess, sourceLocation: sourceLocation)
    } catch is DecodingError {
        // Expected - decoding should fail
    } catch {
        Issue.record(TestError.unexpectedErrorType(error), sourceLocation: sourceLocation)
    }
}

// MARK: - Test Errors

enum TestError: Error, CustomStringConvertible {
    case invalidJSONString
    case unexpectedCase(String)
    case unexpectedSuccess
    case unexpectedErrorType(Error)

    var description: String {
        switch self {
        case .invalidJSONString:
            return "Invalid JSON string"
        case .unexpectedCase(let message):
            return "Unexpected case: \(message)"
        case .unexpectedSuccess:
            return "Expected decoding to fail, but it succeeded"
        case .unexpectedErrorType(let error):
            return "Expected DecodingError, but got \(type(of: error)): \(error)"
        }
    }
}
