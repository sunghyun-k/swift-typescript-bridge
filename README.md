# Swift TypeScript Bridge

A Swift macro library that brings TypeScript-style union types to Swift, providing type-safe unions with automatic Codable support.

> **⚠️ Note:** This library is currently under development.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)

## Features

- 🚀 **TypeScript-like Union Types**: Create union types similar to TypeScript's literal and type unions
- 🔒 **Type Safety**: Full compile-time type checking with Swift's type system
- 📦 **Automatic Codable**: Built-in JSON serialization/deserialization support
- 🌐 **Unicode Support**: Works with any characters including emojis, Korean, Arabic, and Swift keywords
- ⚡ **Zero Runtime Cost**: Fully resolved at compile time using Swift macros

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sunghyun-k/swift-typescript-bridge.git", from: "0.1.0")
]
```

Or add it through Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Quick Start

### String Literal Unions

Create union types from string literals, similar to TypeScript's literal union types:

```swift
import TypeScriptBridge

struct Event: Codable {
    @Union("click", "hover", "focus", "blur") enum EventType {}
    
    let type: EventType
    let timestamp: Date
}

// Usage
let event = Event(type: .click, timestamp: Date())

// JSON serialization
let jsonData = try JSONEncoder().encode(event)
// {"type":"click","timestamp":"2024-01-01T12:00:00Z"}

// JSON deserialization
let decoded = try JSONDecoder().decode(Event.self, from: jsonData)
print(decoded.type) // EventType.click
```

### Type Unions

Create union types from Swift types, similar to TypeScript's union types:

```swift
struct User: Codable {
    let name: String
    let email: String
}

struct Organization: Codable {
    let name: String
    let memberCount: Int
}

@Union(User.self, Organization.self) enum Entity {}

// Usage
let user = User(name: "Alice", email: "alice@example.com")
let entity = Entity.User(user)

// JSON handling - automatically determines the correct type
let jsonData = """
{"name": "Acme Corp", "memberCount": 100}
""".data(using: .utf8)!

let decoded = try JSONDecoder().decode(Entity.self, from: jsonData)
switch decoded {
case .User(let user):
    print("User: \(user.name)")
case .Organization(let org):
    print("Organization: \(org.name) with \(org.memberCount) members")
}
```

## Advanced Usage

### Special Characters

The macro supports any characters, including:
- **Unicode**: `"한국어"`, `"日本語"`, `"العربية"`
- **Emojis**: `"🎉"`, `"🚀"`, `"💯"`
- **Swift Keywords**: `"class"`, `"func"`, `"var"`
- **Numbers**: `"123invalid"`
- **Symbols**: `"!@#$%^&*()"`

```swift
@Union("🎉", "🚀", "💯", "한국어", "class", "123test") enum SpecialCases {}

let special = SpecialCases.`🎉`  // Backticks are auto-generated for special cases
```

### Complex JSON Handling

Type unions automatically handle complex JSON structures:

```swift
struct APIResponse: Codable {
    @Union(SuccessResponse.self, ErrorResponse.self) enum Result {}
    
    let result: Result
}

struct SuccessResponse: Codable {
    let data: [String]
    let count: Int
}

struct ErrorResponse: Codable {
    let error: String
    let code: Int
}

// The decoder tries SuccessResponse first, then ErrorResponse
let response = try JSONDecoder().decode(APIResponse.self, from: jsonData)
```

### Nested Unions

Unions can be nested and combined:

```swift
struct UIEvent: Codable {
    @Union("mouse", "keyboard", "touch") enum InputType {}
    
    @Union(MouseEvent.self, KeyboardEvent.self, TouchEvent.self) enum EventData {}
    
    let inputType: InputType
    let data: EventData
}
```

## Requirements

- Swift 6.2 or later

## How It Works

Swift TypeScript Bridge uses Swift macros to generate code at compile time:

1. **Literal Unions**: Creates enum cases with backticks for special characters
2. **Type Unions**: Creates enum cases with associated values for each type
3. **Codable Support**: Generates custom `init(from:)` and `encode(to:)` implementations
4. **Access Control**: Applies the same access modifier to all generated code

The generated code is fully visible in Xcode's macro expansion view, making debugging straightforward.

## Comparison with TypeScript

| TypeScript | Swift TypeScript Bridge |
|------------|-------------------------|
| `type EventType = "click" \| "hover"` | `@Union("click", "hover") enum EventType {}` |
| `type Entity = User \| Organization` | `@Union(User.self, Organization.self) enum Entity {}` |
| Automatic JSON handling | Automatic Codable conformance |
| Runtime type checking | Compile-time type safety |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
