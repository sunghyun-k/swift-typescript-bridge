# Discriminated Unions

Decode a TypeScript-style tagged union in one shot, without trying each variant.

## The Pattern

In TypeScript:

```typescript
interface Success { status: "ok"; data: Data }
interface Failure { status: "error"; error: ErrorBody }
type Response = Success | Failure;
```

Translating to Swift requires three pieces:

1. A literal `@Union` enum naming the discriminator values.
2. A `@UnionDiscriminator("status")` on each variant pointing at the discriminator field.
3. A `@Union` over those variants.

```swift
@UnionDiscriminator("status")
struct Success: Codable {
    @Union("ok") enum Status {}
    let status: Status
    let data: Data
}

@UnionDiscriminator("status")
struct Failure: Codable {
    @Union("error") enum Status {}
    let status: Status
    let error: ErrorBody
}

@Union(Success.self, Failure.self) enum Response {}
```

## How Decoding Works

When `Response` decodes incoming JSON, the macro-generated `init(from:)`:

1. **Fast path.** Iterates the variants and, for each one whose type conforms to `TypeDiscriminated`, tries to decode the variant directly. The variant's own `Codable` already enforces the literal discriminator, so this either succeeds immediately or fails fast.
2. **Fallback.** If none matched (e.g. some variants don't have `@UnionDiscriminator`), it falls back to trying each type with a single-value container.

The fast path matters when variants have overlapping fields — without it, a `Success` JSON could accidentally satisfy `Failure`'s shape and bind to the wrong case.

## Practical Tip

Always pair `@UnionDiscriminator` with the variants in a `@Union(...types)`. Mixing some-discriminated and some-not is supported but invites ambiguity; the macro decodes those non-discriminated variants in declaration order during fallback.
