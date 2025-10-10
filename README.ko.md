# Swift TypeScript Bridge

TypeScript 스타일의 유니온 타입을 Swift로 가져오세요. 타입 안정성과 자동 JSON 인코딩/디코딩을 제공합니다.

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-blue.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgray.svg)](https://github.com/sunghyun-k/swift-typescript-bridge)

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
    .package(url: "https://github.com/sunghyun-k/swift-typescript-bridge.git", from: "0.1.0")
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
let entity = Entity.User(user)
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

Swift 매크로 기반—모든 코드 생성은 컴파일 타임에 발생하며 런타임 오버헤드가 전혀 없습니다. Xcode에서 매크로를 확장하면 생성된 코드를 정확히 볼 수 있습니다.

## 요구사항

- Swift 6.2+
- 플랫폼: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, Linux

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
