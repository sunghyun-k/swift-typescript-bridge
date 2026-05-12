#  ``TypeScriptBridge``

Bring TypeScript-style union types and `extends` semantics to Swift, with automatic `Codable` conformance and zero runtime overhead.

## Overview

`TypeScriptBridge` is a small set of attached macros that map TypeScript's most idiomatic type-level patterns onto Swift:

| TypeScript                                       | TypeScriptBridge                              |
|--------------------------------------------------|-----------------------------------------------|
| `type S = "a" \| "b"`                            | `@Union("a", "b") enum S {}`                  |
| `type C = 200 \| 404`                            | `@Union(200, 404) enum C {}`                  |
| `type Entity = User \| Org`                      | `@Union(User.self, Org.self) enum Entity {}`  |
| Discriminated unions (`status: "ok"`)            | `@UnionDiscriminator("status")`               |
| `interface B extends A`                          | `@Extends(A.self) struct B { ... }`           |

All four macros generate their code at compile time using `swift-syntax`. Nothing runs at runtime that you couldn't have written yourself.

## Topics

### Literal Unions

Map literal-typed TypeScript unions to Swift enums with automatic `Codable` and `Equatable`.

- ``Union(_:)-1n9oh``

### Type Unions

Combine multiple Swift types into a single enum, with optional discriminator-based fast-path decoding.

- ``Union(_:)-9nzkw``
- ``UnionDiscriminator(_:)``
- ``TypeDiscriminated``

### Struct Extension

Bring TypeScript's `interface B extends A` to Swift `struct`s, with flat JSON and property forwarding.

- ``Extends(_:)``
- ``_ExtendsParent``

### Internal Protocols

Used by the macros — you rarely conform to these directly.

- ``_LiteralType``

### Articles

- <doc:GettingStarted>
- <doc:DiscriminatedUnions>
- <doc:StructExtension>
