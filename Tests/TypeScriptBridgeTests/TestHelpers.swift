import Testing
import Foundation
@testable import TypeScriptBridge

// MARK: - Test Helpers

/// Helper function to encode and decode a value, verifying round-trip serialization
func roundTrip<T: Codable & Equatable>(
    _ value: T,
    dateStrategy: DateEncodingStrategy = .iso8601
) throws -> T {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = dateStrategy
    let data = try encoder.encode(value)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateStrategy == .iso8601 ? .iso8601 : .deferredToDate
    return try decoder.decode(T.self, from: data)
}

/// Helper function to encode a value and return JSON data
func encodeToJSON<T: Codable>(
    _ value: T,
    dateStrategy: DateEncodingStrategy = .iso8601
) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = dateStrategy
    return try encoder.encode(value)
}

/// Helper function to decode JSON data to a value
func decodeFromJSON<T: Codable>(
    _ type: T.Type,
    from data: Data,
    dateStrategy: DateDecodingStrategy = .iso8601
) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = dateStrategy
    return try decoder.decode(type, from: data)
}

/// Helper function to decode JSON string to a value
func decodeFromJSON<T: Codable>(
    _ type: T.Type,
    from jsonString: String,
    dateStrategy: DateDecodingStrategy = .iso8601
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
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    guard let data = jsonString.data(using: .utf8) else {
        Issue.record("Invalid JSON string", fileID: file, filePath: file, line: Int(line))
        return
    }

    do {
        _ = try decodeFromJSON(type, from: data)
        Issue.record("Expected decoding to fail, but it succeeded", fileID: file, filePath: file, line: Int(line))
    } catch is DecodingError {
        // Expected - decoding should fail
    } catch {
        Issue.record("Expected DecodingError, but got \(type(of: error)): \(error)", fileID: file, filePath: file, line: Int(line))
    }
}

// MARK: - Date Encoding Strategy Extension

extension DateEncodingStrategy {
    static var iso8601: DateEncodingStrategy {
        .iso8601
    }
}

extension DateDecodingStrategy {
    static var iso8601: DateDecodingStrategy {
        .iso8601
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case invalidJSONString
    case unexpectedCase(String)
}
