# Getting Started

Add `TypeScriptBridge`, then declare your first union in a single line.

## Install

In your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sunghyun-k/swift-typescript-bridge.git", from: "0.4.0")
]
```

Then add the library product to any target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "TypeScriptBridge", package: "swift-typescript-bridge")
    ]
)
```

## Your First Literal Union

```swift
import TypeScriptBridge

@Union("pending", "approved", "rejected") enum Status {}

struct Application: Codable {
    let id: String
    let status: Status
}

let json = #"{"id": "abc", "status": "approved"}"#.data(using: .utf8)!
let app = try JSONDecoder().decode(Application.self, from: json)
print(app.status)   // Status.`approved`
```

## What the Macro Generated

Right-click `@Union` in Xcode and choose **Expand Macro** to see the generated `enum`, `rawValue`, `init(from:)`, and `encode(to:)`. Everything is compile-time; the runtime cost of decoding `Application` is identical to writing the enum and `Codable` by hand.

## Next Steps

- <doc:DiscriminatedUnions> — pick the right case from JSON by a discriminator field.
- <doc:StructExtension> — model TypeScript's `interface B extends A` pattern.
