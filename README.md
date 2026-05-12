# Swift TypeScript Bridge

Bring TypeScript-style union types to Swift with type safety and automatic JSON encoding/decoding.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsunghyun-k%2Fswift-typescript-bridge%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sunghyun-k/swift-typescript-bridge)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsunghyun-k%2Fswift-typescript-bridge%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sunghyun-k/swift-typescript-bridge)
[![CI](https://github.com/sunghyun-k/swift-typescript-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/sunghyun-k/swift-typescript-bridge/actions/workflows/ci.yml)

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
struct ClickEvent {
    var x: Int
    var y: Int
}

let c = ClickEvent(BaseEvent(timestamp: 0), x: 10, y: 20)
c.timestamp  // forwarded from BaseEvent
c.x          // 10

// JSON: {"timestamp":0,"x":10,"y":20} — flat!
```

**Narrowing parent properties:** A child can redeclare a parent property to narrow its type (e.g., parent's `String` → child's literal union). The child's stored property shadows the forwarded parent property, and the narrower type is enforced on decode.

```swift
struct Event: Codable {
    var kind: String   // parent: any string
    var name: String
}

@Extends(Event.self)
struct ClickEvent {
    @Union("click") enum Kind {}
    var kind: Kind     // child: narrowed to "click"
}
```

**Limitations:**

- Property overrides with incompatible JSON representations (e.g., parent `Int`, child `String`) will fail to decode.
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

Built on Swift macros—all code generation happens at compile time with zero runtime overhead. Right-click the macro and choose **Expand Macro** in Xcode to inspect the generated code, or skim the cheat-sheet below.

### Macro Expansion Cheat-Sheet

#### `@Union(...literals)`

```swift
// You write:
@Union("click", "hover") enum EventType {}

// Macro generates (roughly):
enum EventType {
    case `click`
    case `hover`
}
extension EventType: Codable, Equatable {
    var rawValue: String {
        switch self {
        case .`click`:  return "click"
        case .`hover`:  return "hover"
        }
    }
    init?(rawValue: String) { /* … */ }
    init(from decoder: Decoder) throws { /* singleValueContainer + Self(rawValue:) */ }
    func encode(to encoder: Encoder) throws { /* singleValueContainer */ }
}
```

#### `@Union(...types)`

```swift
// You write:
@Union(User.self, Organization.self) enum Entity {}

// Macro generates (roughly):
enum Entity {
    case user(User)
    case organization(Organization)
}
extension Entity: Codable {
    init(from decoder: Decoder) throws {
        // 1) Try each TypeDiscriminated case directly (fast path)
        // 2) Fall back to sequential single-value decode
    }
    func encode(to encoder: Encoder) throws { /* singleValueContainer */ }
}
```

#### `@UnionDiscriminator("key")`

```swift
// You write:
@UnionDiscriminator("type")
struct ClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    let x: Int
}

// Macro adds (just the protocol witness — your struct itself is unchanged):
extension ClickEvent: TypeDiscriminated {
    typealias DiscriminatorType = EventType
    static let discriminatorKey = "type"
}
```

#### `@Extends(Parent.self)`

```swift
// You write:
@Extends(BaseEvent.self)
struct ClickEvent {
    var x: Int
    var y: Int
}

// Macro generates (roughly):
struct ClickEvent {
    var _parent: BaseEvent
    var x: Int
    var y: Int
    init(_ parent: BaseEvent, x: Int, y: Int) { /* … */ }
}
extension ClickEvent: Codable, _ExtendsParent {
    private enum CodingKeys: String, CodingKey { case x; case y }
    init(from decoder: Decoder) throws {
        // Decode parent first (flat JSON), then own keys override
        self._parent = try BaseEvent(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try c.decode(Int.self, forKey: .x)
        self.y = try c.decode(Int.self, forKey: .y)
    }
    func encode(to encoder: Encoder) throws {
        try _parent.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
    }
}
```

## Tuple-Literal Unions Are Not Supported

TypeScript permits `type Pair = [1, 2] | [3, 4]` — a union of *tuple* literals. We deliberately do not support this in `@Union(...)`:

- Swift 6.2's arbitrary-identifier syntax (`` ` … ` ``) only accepts identifier-like characters, so a case name like `` `[1, 2]` `` is illegal — there is no clean automatic name to pick.
- The pattern is rare in real TypeScript codebases. Existing patterns produce a clearer Swift model:

```swift
// Instead of `type Pair = [1, 2] | [3, 4]`, model each tuple as a struct
// and union the structs — this also gives every variant a proper name.

struct PairOneTwo: Codable { let a = 1; let b = 2 }
struct PairThreeFour: Codable { let a = 3; let b = 4 }

@Union(PairOneTwo.self, PairThreeFour.self) enum Pair {}
```

## More Examples

See the [`Examples/`](./Examples) directory for realistic, end-to-end TypeScript ↔ Swift mappings (analytics events, API responses, discriminated webhooks).

## Requirements

- Swift 6.2+
- Platforms: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, Linux

## License

MIT License - see [LICENSE](LICENSE)
