# Swift TypeScript Bridge

TypeScript 스타일의 유니온 타입을 Swift로 가져오세요. 타입 안정성과 자동 JSON 인코딩/디코딩을 제공합니다.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsunghyun-k%2Fswift-typescript-bridge%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sunghyun-k/swift-typescript-bridge)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsunghyun-k%2Fswift-typescript-bridge%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sunghyun-k/swift-typescript-bridge)
[![CI](https://github.com/sunghyun-k/swift-typescript-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/sunghyun-k/swift-typescript-bridge/actions/workflows/ci.yml)

[English Documentation](./README.md)

## 왜 이 라이브러리인가?

TypeScript와 Swift를 함께 사용해본 적이 있다면, TypeScript의 유연한 유니온 타입을 Swift로 변환하는 고통을 알 것입니다. 이 라이브러리가 그 문제를 해결합니다.

**TypeScript**
```typescript
type Status = "pending" | "approved" | "rejected";
type StatusCode = 200 | 404 | 500;
type Response = SuccessResponse | ErrorResponse;
```

**Swift (이 라이브러리 없이)**
```swift
// 장황한 enum 정의, 수동 Codable 구현, 별도의 rawValue 처리...
enum Status: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}
```

**Swift (이 라이브러리 사용)**
```swift
@Union("pending", "approved", "rejected") enum Status {}
@Union(200, 404, 500) enum StatusCode {}
@Union(SuccessResponse.self, ErrorResponse.self) enum Response {}
// Codable 준수 자동 포함 ✨
```

## 설치

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/sunghyun-k/swift-typescript-bridge.git", from: "0.3.0")
]
```

또는 Xcode에서: **File → Add Package Dependencies**

## 핵심 기능

### 1. 리터럴 유니온

TypeScript의 리터럴 유니온을 Swift로 직접 매핑합니다.

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

문자열, 정수, 실수, 불리언 모두 지원:

```swift
@Union("auto", 100, true, 2.5) enum ConfigValue {}
```

### 2. 타입 유니온

서로 다른 Swift 타입을 하나의 유니온으로 결합합니다.

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

### 3. 판별 유니온 (Discriminated Unions)

핵심 기능: 판별자 필드를 사용한 효율적인 JSON 디코딩.

```typescript
// TypeScript - 판별 유니온 패턴
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
// Swift - 동일한 패턴, 동일한 효율성
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

// JSON 디코딩 - 빠르고 정확한 타입 검출을 위해 판별자 필드를 먼저 확인
let response = try JSONDecoder().decode(ApiResponse.self, from: jsonData)
```

**왜 판별 유니온이 중요한가:** `@UnionDiscriminator` 없이는 디코더가 성공할 때까지 각 타입을 순차적으로 시도합니다—느리고 오류가 발생하기 쉽습니다. 이 매크로를 사용하면 디코더가 판별자 필드를 먼저 확인하고 올바른 타입을 즉시 디코딩합니다.

### 4. 타입 확장 (Extends)

TypeScript의 `interface B extends A` 패턴을 Swift struct로 가져옵니다. flat JSON 인코딩/디코딩과 프로퍼티 forwarding을 자동 생성합니다.

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
c.timestamp  // BaseEvent에서 forwarding
c.x          // 10

// JSON: {"timestamp":0,"x":10,"y":20} — flat!
```

**부모 프로퍼티 좁히기:** 자식이 부모 프로퍼티를 재선언해 타입을 좁힐 수 있습니다 (예: 부모의 `String` → 자식의 literal union). 자식의 stored property가 forwarding된 부모 프로퍼티보다 우선 해석되며, 좁혀진 타입이 디코드 시 강제됩니다.

```swift
struct Event: Codable {
    var kind: String   // 부모: 임의의 문자열
    var name: String
}

@Extends(Event.self)
struct ClickEvent {
    @Union("click") enum Kind {}
    var kind: Kind     // 자식: "click"으로 좁힘
}
```

**제약:**

- JSON 표현이 호환되지 않는 프로퍼티 오버라이드는 디코드 실패 (예: 부모 `Int`, 자식 `String`)
- MVP는 단일 parent만 지원

## 실제 사용 예시

TypeScript 프론트엔드에서 보낸 웹 분석 이벤트 파싱:

```typescript
// TypeScript 프론트엔드
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
// Swift 백엔드
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

// 들어오는 분석 데이터 파싱
let analyticsEvent = try JSONDecoder().decode(WebEvent.self, from: jsonData)
```

## 작동 원리

Swift 매크로 기반—모든 코드 생성은 컴파일 타임에 발생하며 런타임 오버헤드가 전혀 없습니다. Xcode에서 매크로 attribute 를 우클릭 → **Expand Macro** 로 생성된 코드를 직접 확인할 수 있고, 아래 치트시트로도 대략적인 형태를 파악할 수 있습니다.

### 매크로 전개 치트시트

#### `@Union(...리터럴들)`

```swift
// 작성:
@Union("click", "hover") enum EventType {}

// 생성 (대략):
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

#### `@Union(...타입들)`

```swift
// 작성:
@Union(User.self, Organization.self) enum Entity {}

// 생성 (대략):
enum Entity {
    case user(User)
    case organization(Organization)
}
extension Entity: Codable {
    init(from decoder: Decoder) throws {
        // 1) TypeDiscriminated 케이스를 우선 시도 (fast path)
        // 2) 실패하면 순차 single-value 디코드로 fallback
    }
    func encode(to encoder: Encoder) throws { /* singleValueContainer */ }
}
```

#### `@UnionDiscriminator("key")`

```swift
// 작성:
@UnionDiscriminator("type")
struct ClickEvent: Codable {
    @Union("click") enum EventType {}
    let type: EventType
    let x: Int
}

// 생성 (struct 본체는 그대로, 프로토콜 증명만 추가):
extension ClickEvent: TypeDiscriminated {
    typealias DiscriminatorType = EventType
    static let discriminatorKey = "type"
}
```

#### `@Extends(Parent.self)`

```swift
// 작성:
@Extends(BaseEvent.self)
struct ClickEvent {
    var x: Int
    var y: Int
}

// 생성 (대략):
struct ClickEvent {
    var _parent: BaseEvent
    var x: Int
    var y: Int
    init(_ parent: BaseEvent, x: Int, y: Int) { /* … */ }
}
extension ClickEvent: Codable, _ExtendsParent {
    private enum CodingKeys: String, CodingKey { case x; case y }
    init(from decoder: Decoder) throws {
        // flat JSON: 부모를 먼저 디코드 → 자식 키가 override
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

## Tuple-Literal Union 미지원

TypeScript 에는 `type Pair = [1, 2] | [3, 4]` 처럼 **튜플** 리터럴 유니온이 있지만 `@Union(...)` 에서는 의도적으로 지원하지 않습니다:

- Swift 6.2 의 임의 식별자 (`` ` … ` ``) 는 식별자형 문자만 허용 — `` `[1, 2]` `` 같은 case 명이 문법적으로 불가능해서 자동 명명이 깔끔하지 않습니다.
- 실전 TS 코드베이스에서 이 패턴은 드뭅니다. 각 튜플을 struct 로 모델링한 뒤 union 하는 방식이 결과적으로 더 명확합니다:

```swift
struct PairOneTwo: Codable { let a = 1; let b = 2 }
struct PairThreeFour: Codable { let a = 3; let b = 4 }

@Union(PairOneTwo.self, PairThreeFour.self) enum Pair {}
```

## 더 많은 예제

분석 이벤트, API 응답, 판별 웹훅 등 실전 TypeScript ↔ Swift 매핑 패턴은 [`Examples/`](./Examples) 디렉터리에서 확인할 수 있습니다.

## 요구사항

- Swift 6.2+
- 플랫폼: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, Linux

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
