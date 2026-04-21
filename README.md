# Swift TypeScript Bridge

Bring TypeScript-style union types to Swift with type safety and automatic JSON encoding/decoding.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)

[한국어 문서](./README.ko.md)

## Why This Library?

If you've worked with TypeScript and Swift together, you know the pain of translating TypeScript's flexible union types into Swift. This library solves that.

**TypeScript**
```typescript
type Status = "pending" | "approved" | "rejected";
type StatusCode = 200 | 404 | 500;
type Response = SuccessResponse | ErrorResponse;
```

**Swift (without this library)**
```swift
// Verbose enum definitions, manual Codable implementation, separate rawValue handling...
enum Status: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}
```

**Swift (with this library)**
```swift
@Union("pending", "approved", "rejected") enum Status {}
@Union(200, 404, 500) enum StatusCode {}
@Union(SuccessResponse.self, ErrorResponse.self) enum Response {}
// Codable conformance included ✨
```

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/sunghyun-k/swift-typescript-bridge.git", from: "0.3.0")
]
```

Or in Xcode: **File → Add Package Dependencies**

## Core Features

### 1. Literal Unions

Map TypeScript literal unions directly to Swift.

```typescript
// TypeScript
interface Event {
    type: "click" | "hover" | "focus";
    timestamp: number;
}
```

```swift
// Swift
@Union("click", "hover", "focus") enum EventType {}

struct Event: Codable {
    let type: EventType
    let timestamp: Double
}

let event = Event(type: .click, timestamp: Date().timeIntervalSince1970)
```

Works with strings, integers, doubles, and booleans:

```swift
@Union("auto", 100, true, 2.5) enum ConfigValue {}
```

### 2. Type Unions

Combine different Swift types into one union.

```typescript
// TypeScript
type Entity = User | Organization;
```

```swift
// Swift
@Union(User.self, Organization.self) enum Entity {}

let user = User(name: "Alice")
let entity = Entity.user(user)
```

### 3. Discriminated Unions

The killer feature: efficient JSON decoding with discriminator fields.

```typescript
// TypeScript - Discriminated union pattern
interface SuccessResponse {
    status: "success";
    data: { id: string; name: string };
}

interface ErrorResponse {
    status: "error";
    error: { code: string; message: string };
}

type ApiResponse = SuccessResponse | ErrorResponse;
```

```swift
// Swift - Same pattern, same efficiency
@UnionDiscriminator("status")
struct SuccessResponse: Codable {
    @Union("success") enum Status {}
    let status: Status
    let data: SuccessData

    struct SuccessData: Codable {
        let id: String
        let name: String
    }
}

@UnionDiscriminator("status")
struct ErrorResponse: Codable {
    @Union("error") enum Status {}
    let status: Status
    let error: ErrorData

    struct ErrorData: Codable {
        let code: String
        let message: String
    }
}

@Union(SuccessResponse.self, ErrorResponse.self) enum ApiResponse {}

// JSON decoding - discriminator field checked first for fast, accurate type detection
let response = try JSONDecoder().decode(ApiResponse.self, from: jsonData)
```

**Why discriminated unions matter:** Without `@UnionDiscriminator`, the decoder tries each type sequentially until one succeeds—slow and error-prone. With it, the decoder checks the discriminator field first and decodes the correct type immediately.

### 4. Type Extension (Extends)

Bring TypeScript's `interface B extends A` pattern to Swift structs. Flat JSON encoding/decoding and property forwarding are generated automatically.

```typescript
// TypeScript
interface BaseEvent {
    timestamp: number;
}
interface ClickEvent extends BaseEvent {
    x: number;
    y: number;
}
```

```swift
// Swift
struct BaseEvent: Codable {
    var timestamp: Double
}

@Extends(BaseEvent.self)
@dynamicMemberLookup
struct ClickEvent {
    var x: Int
    var y: Int
}

let c = ClickEvent(BaseEvent(timestamp: 0), x: 10, y: 20)
c.timestamp  // forwarded from BaseEvent
c.x          // 10

// JSON: {"timestamp":0,"x":10,"y":20} — flat!
```

**Limitations:**

- `@dynamicMemberLookup` must be declared on the struct yourself — without it, `c.timestamp` won't resolve; parent fields are still accessible via `c._parent.timestamp`.
- Property name collisions with different types across parent/child are not supported (decode will fail).
- MVP supports a single parent only.

## Real-World Example

Parse web analytics events from your TypeScript frontend:

```typescript
// TypeScript Frontend
interface PageViewEvent {
    event: "page_view";
    page: string;
}

interface UserActionEvent {
    event: "click" | "scroll";
    element: string;
}

type WebEvent = PageViewEvent | UserActionEvent;
```

```swift
// Swift Backend
@UnionDiscriminator("event")
struct PageViewEvent: Codable {
    @Union("page_view") enum EventType {}
    let event: EventType
    let page: String
}

@UnionDiscriminator("event")
struct UserActionEvent: Codable {
    @Union("click", "scroll") enum EventType {}
    let event: EventType
    let element: String
}

@Union(PageViewEvent.self, UserActionEvent.self) enum WebEvent {}

// Parse incoming analytics
let analyticsEvent = try JSONDecoder().decode(WebEvent.self, from: jsonData)
```

## How It Works

Built on Swift macros—all code generation happens at compile time with zero runtime overhead. Expand macros in Xcode to see exactly what's generated.

## Requirements

- Swift 6.2+
- Platforms: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, Linux

## License

MIT License - see [LICENSE](LICENSE)
