# Swift TypeScript Bridge

A Swift macro library that brings TypeScript-style union types to Swift, providing type-safe unions with automatic Codable support.

> **⚠️ Note:** This library is currently under development.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)

## Features

- 🚀 **TypeScript-like Union Types**: Create union types similar to TypeScript's literal and type unions
- 🔒 **Type Safety**: Full compile-time type checking with Swift's type system
- 📦 **Automatic Codable**: Built-in JSON serialization/deserialization support
- 🔢 **Multiple Literal Types**: Support for String, Int, Double, and Bool literals
- 🌐 **Unicode Support**: Works with any characters including emojis and Swift keywords
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

```swift
// TypeScript: type EventType = "click" | "hover" | "focus"
@Union("click", "hover", "focus") enum EventType {}

struct Event: Codable {
    let type: EventType
    let timestamp: Date
}

let event = Event(type: .click, timestamp: Date())
```

### Numeric Literal Unions

```swift
// TypeScript: type StatusCode = 200 | 404 | 500
@Union(200, 404, 500) enum StatusCode {}

// TypeScript: type Version = 1.0 | 2.0 | 3.0
@Union(1.0, 2.0, 3.0) enum Version {}

struct APIResponse: Codable {
    let statusCode: StatusCode
    let message: String
}
```

### Boolean Literal Unions

```swift
// TypeScript: type Flag = true | false
@Union(true, false) enum Flag {}

struct FeatureFlag: Codable {
    let enabled: Flag
    let feature: String
}
```

### Type Unions

```swift
// TypeScript: type Entity = User | Organization  
@Union(User.self, Organization.self) enum Entity {}

let user = User(name: "Alice", email: "alice@example.com")
let entity = Entity.User(user)
```

## TypeScript Comparison

| TypeScript | Swift TypeScript Bridge |
|------------|-------------------------|
| `type EventType = "click" \| "hover"` | `@Union("click", "hover") enum EventType {}` |
| `type StatusCode = 200 \| 404 \| 500` | `@Union(200, 404, 500) enum StatusCode {}` |
| `type Version = 1.0 \| 2.0 \| 3.0` | `@Union(1.0, 2.0, 3.0) enum Version {}` |
| `type Flag = true \| false` | `@Union(true, false) enum Flag {}` |
| `type Entity = User \| Organization` | `@Union(User.self, Organization.self) enum Entity {}` |
| Automatic JSON handling | Automatic Codable conformance |
| Runtime type checking | Compile-time type safety |

## Requirements

- Swift 6.2 or later

## How It Works

Swift TypeScript Bridge uses Swift macros to generate code at compile time:

1. **Literal Unions**: Creates enum cases with backticks for special characters
2. **Type Unions**: Creates enum cases with associated values for each type  
3. **Codable Support**: Generates custom `init(from:)` and `encode(to:)` implementations
4. **Access Control**: Applies the same access modifier to all generated code

The generated code is fully visible in Xcode's macro expansion view, making debugging straightforward.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
