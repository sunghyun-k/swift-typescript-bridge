# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

TypeScript 의 union / `extends` 패턴을 Swift 매크로로 가져오는 SwiftPM 라이브러리. 모든 코드 생성은 컴파일 타임에 swift-syntax 로 이뤄지며 런타임 오버헤드는 없다.

- Swift tools: 6.2
- swift-syntax 범위: `600.0.0 ..< 605.0.0` (Xcode 16 / 16.4 / 26 호환 목적으로 600 라인 전체를 받음 — 신형 `MemberMacro.expansion(... conformingTo: ...)` 시그니처 사용을 위해 하한이 600. 상한은 좁히지 말 것)
- 플랫폼: iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+ / macCatalyst 13+ / Linux

## 자주 쓰는 명령

```bash
swift build                              # 전체 빌드 (매크로 플러그인 + 라이브러리)
swift test                               # 모든 Swift Testing 케이스 실행
swift test --filter ExtendsMacroTests    # 특정 테스트 스위트만
swift test --filter testExtendsFlatJSONEncode  # 단일 케이스
swift package clean                      # 매크로 캐시 꼬일 때
swift-format --in-place --recursive Sources Tests  # .swift-format 규칙 적용
```

테스트는 XCTest 가 아니라 **Swift Testing** (`import Testing`, `@Test`, `#expect`) 을 사용한다. `Tests/TypeScriptBridgeTests/TestHelpers.swift` 의 `roundTrip` / `decodeFromJSON` / `expectDecodingFailure` 헬퍼를 활용하면 보일러플레이트를 줄일 수 있다.

## 아키텍처

두 개의 타깃이 짝을 이룬다:

- `TypeScriptBridgeMacros` (`.macro`) — swift-syntax 기반 매크로 구현. 사용자 코드에 직접 노출되지 않는다.
- `TypeScriptBridge` (`.target`) — 공개 매크로 선언과 런타임 프로토콜(`_LiteralType`, `TypeDiscriminated`, `_ExtendsParent`). `TypeScriptBridgeMacros` 에 의존.

### 네 가지 매크로의 책임 분담

| 매크로 | 적용 대상 | 구현 파일 | 생성 결과 |
|---|---|---|---|
| `@Union(literal, ...)` | `enum` | `LiteralUnionMacro.swift` | 각 리터럴별 enum case + `rawValue` / `Codable` / `Equatable`. 동질 타입이면 단일 타입, 혼합이면 `any _LiteralType` 분기 |
| `@Union(T.self, ...)` | `enum` | `TypeUnionMacro.swift` | associated value 가 붙은 case + `Codable`. 디코딩은 ①`TypeDiscriminated` 케이스 우선 시도 → ②순차 fallback |
| `@UnionDiscriminator("key")` | `struct` | `UnionDiscriminatorMacro.swift` | `TypeDiscriminated` 준수 (`DiscriminatorType`, `discriminatorKey`). `key` 필드가 struct 안의 `@Union` enum 을 가리키고 있어야 함 |
| `@Extends(Parent.self)` | `struct` | `ExtendsMacro.swift` | `_parent` 저장 + 편의 init + flat JSON `Codable` + `_ExtendsParent` (dynamic member lookup 으로 부모 프로퍼티 포워딩) |

### 중요한 매크로 간 결합

- **`@Union(T.self, ...)` + `@UnionDiscriminator`**: type union 디코더는 각 케이스 타입이 `TypeDiscriminated` 인지 런타임 검사한다 (`Type.self is any TypeDiscriminated.Type`). 따라서 효율적 분기를 원하면 모든 변종 struct 에 `@UnionDiscriminator` 를 붙여야 한다. 안 붙이면 단순 순차 시도로 fallback 된다 — 동작은 하지만 모호한 JSON 에서 잘못된 매칭이 날 수 있다.
- **`@UnionDiscriminator("type")` 의 사전조건**: 지정한 프로퍼티가 같은 struct 안에 선언돼 있어야 하고, 그 프로퍼티의 타입(예: `EventType`) enum 이 동일 struct 안에 nested 로 존재해야 한다. 둘 중 하나라도 빠지면 `fieldNotFound` / `enumNotFound` 컴파일 에러.
- **`@Extends` 의 프로퍼티 narrowing**: 자식이 부모와 같은 이름의 stored property 를 선언하면 자식 것이 shadow 한다(JSON 키 충돌이 의도). 디코드 단계에서는 먼저 부모를 디코드한 뒤 자식 키를 덮어쓰는 구조이므로, **부모/자식의 JSON 표현이 호환되지 않으면**(`Int` ↔ `String` 등) 의도적으로 명확한 에러 메시지를 던지도록 부모 디코드를 do-catch 로 감싸고 있다 (`ExtendsMacro.swift:127-145`). 이 분기는 narrowing 동작의 핵심이므로 단순화하지 말 것.
- **단일 부모만 지원**: `@Extends` 는 MVP 단계에서 부모 1개만 받는다. 다중 상속을 추가하려면 `_ExtendsParent` 의 `Parent` associatedtype 모델부터 재설계가 필요하다.

### enum case 이름 규칙

리터럴 union 의 case 이름은 항상 백틱으로 감싼다 (`` `click` ``, `` `404` ``, `` `🎉` ``). 이건 키워드/숫자 시작/이모지/한글을 일관되게 받기 위한 의도다 — `LiteralUnionMacro.LiteralValue.enumCaseName` 에서 무조건 백틱을 두르므로 일반 식별자도 같은 형태가 된다. 사용처에서도 `.click` 처럼 적으면 Swift 가 자동으로 매칭하지만, 매크로 출력을 직접 읽을 때 헷갈리지 말 것.

### 접근 제어자 전파

매크로는 적용 대상의 access modifier (`public`/`internal`/`package`/`fileprivate`) 를 감지해 생성된 case·init·메서드에 그대로 붙인다. `private` 은 제외 — extension 으로 생성되는 멤버에 `private` 을 붙이면 의미가 깨지기 때문(`LiteralUnionMacro.swift:57` 의 `$0 == .private ? nil : $0` 패턴). 새 매크로를 추가할 때도 이 규칙을 따라야 한다.

## 릴리스

`X.Y.Z` 형태 태그를 push 하면 `.github/workflows/release.yml` 이 GitHub Release 를 만든다. SemVer 만 통과시키므로 prerelease 태그(`-beta` 등)는 워크플로우 트리거되지 않는다.
