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
- 🎯 **Mixed Type Unions**: Combine different literal types (strings, numbers, booleans) in a single union
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

### Mixed Type Literal Unions

```swift
// TypeScript: type ConfigValue = "auto" | 100 | true | 2.5 | "manual" | false
@Union("auto", 100, true, 2.5, "manual", false) enum ConfigValue {}

struct AppConfig: Codable {
    let theme: ConfigValue      // Can be "auto" or "manual"
    let maxItems: ConfigValue   // Can be 100
    let isEnabled: ConfigValue  // Can be true or false
    let scale: ConfigValue      // Can be 2.5
}

// Usage examples:
let config1 = AppConfig(theme: .`auto`, maxItems: .`100`, isEnabled: .`true`, scale: .`2.5`)
let config2 = AppConfig(theme: .`manual`, maxItems: .`100`, isEnabled: .`false`, scale: .`2.5`)
```

### Type Unions

```swift
// TypeScript: type Entity = User | Organization  
@Union(User.self, Organization.self) enum Entity {}

let user = User(name: "Alice", email: "alice@example.com")
let entity = Entity.User(user)
```

## Advanced Usage

### Web Analytics Events

```typescript
// TypeScript - Frontend analytics events
interface PageViewEvent {
    event: "page_view";
    page: string;
    referrer?: string;
}

interface UserActionEvent {
    event: "click" | "hover" | "focus" | "scroll";
    element: string;
    timestamp: number;
}

interface ConversionEvent {
    event: "purchase" | "signup" | "download";
    value: number;
    currency: "USD" | "EUR" | "GBP";
}

type WebEvent = PageViewEvent | UserActionEvent | ConversionEvent;
```

```swift
// Swift TypeScript Bridge - Parse analytics from web frontend
struct PageViewEvent: Codable {
    @Union("page_view") enum EventType {}
    let event: EventType
    let page: String
    let referrer: String?
}

struct UserActionEvent: Codable {
    @Union("click", "hover", "focus", "scroll") enum EventType {}
    let event: EventType
    let element: String
    let timestamp: Double
}

struct ConversionEvent: Codable {
    @Union("purchase", "signup", "download") enum EventType {}
    let event: EventType
    let value: Double
    @Union("USD", "EUR", "GBP") enum Currency {}
    let currency: Currency
}

@Union(PageViewEvent.self, UserActionEvent.self, ConversionEvent.self) enum WebEvent {}

// JSON Parsing from web analytics
let analyticsJson = """
{
    "event": "click",
    "element": "checkout-button",
    "timestamp": 1640995200
}
"""

let userAction = try JSONDecoder().decode(WebEvent.self, from: analyticsJson.data(using: .utf8)!)
```

### API Response Discrimination

```typescript
// TypeScript - Discriminated union for API responses
interface SuccessResponse {
    status: "success";
    data: {
        id: string;
        name: string;
    };
}

interface ErrorResponse {
    status: "error";
    error: {
        code: string;
        message: string;
    };
}

type ApiResponse = SuccessResponse | ErrorResponse;
```

```swift
// Swift TypeScript Bridge - Parse discriminated API responses
struct SuccessResponse: Codable {
    @Union("success") enum Status {}
    let status: Status
    struct SuccessData: Codable {
        let id: String
        let name: String
    }
    let data: SuccessData
}

struct ErrorResponse: Codable {
    @Union("error") enum Status {}
    let status: Status
    struct ErrorData: Codable {
        let code: String
        let message: String
    }
    let error: ErrorData
}

@Union(SuccessResponse.self, ErrorResponse.self) enum ApiResponse {}

// JSON Parsing from REST API
let successJson = """
{
    "status": "success",
    "data": {
        "id": "user_123",
        "name": "John Doe"
    }
}
"""

let errorJson = """
{
    "status": "error",
    "error": {
        "code": "INVALID_TOKEN",
        "message": "Authentication token is invalid"
    }
}
"""

let successResponse = try JSONDecoder().decode(SuccessResponse.self, from: successJson.data(using: .utf8)!)
let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: errorJson.data(using: .utf8)!)
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
