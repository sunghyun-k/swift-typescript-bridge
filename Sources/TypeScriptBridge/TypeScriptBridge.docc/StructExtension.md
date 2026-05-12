# Struct Extension

Compose Swift `struct`s the way TypeScript composes `interface`s.

## Why Not Inheritance?

Swift `class` inheritance comes with reference semantics, vtables, and `final`/`override` ceremony. TypeScript's `interface B extends A` is a flat structural extension — the JSON contains every field, and `B` just promises *also* to have everything `A` has. `@Extends` recreates that on a value-typed `struct`.

## Single Parent

```swift
struct BaseEvent: Codable {
    var timestamp: Double
}

@Extends(BaseEvent.self)
struct ClickEvent {
    var x: Int
    var y: Int
}

let c = ClickEvent(BaseEvent(timestamp: 0), x: 10, y: 20)
c.timestamp   // forwarded via @dynamicMemberLookup
c.x           // 10

// JSON round-trip is flat: {"timestamp":0,"x":10,"y":20}
```

## Multiple Parents

Combine traits from several base structs:

```swift
struct Timestamped: Codable { var timestamp: Double }
struct Tagged: Codable { var tags: [String] }

@Extends(Timestamped.self, Tagged.self)
struct Article {
    var title: String
}

let a = Article(Timestamped(timestamp: 0), Tagged(tags: ["news"]), title: "Hi")
a.timestamp   // forwarded from Timestamped
a.tags        // forwarded from Tagged
a.title       // own
```

When two parents both declare a property of the same name, the **child's own** property always wins on decode/encode. Between two parents, *earlier-listed* parents win. The macro emits a key-collision summary so unintended overlaps don't go silent.

## Narrowing Parent Properties

A child can redeclare a parent property with a tighter type — for example, narrowing the parent's free-form `String` to a literal `@Union`:

```swift
struct Event: Codable {
    var kind: String
    var name: String
}

@Extends(Event.self)
struct ClickEvent {
    @Union("click") enum Kind {}
    var kind: Kind          // narrowed to just "click"
}
```

The child's `kind: Kind` shadows `Event.kind: String` in both Swift property access and JSON decoding. Mismatched representations (parent `Int`, child `String`) raise a clear `DecodingError` flagging the override.

## When *Not* To Use `@Extends`

If your "extension" is really a *variant* selected by a tag field, you want <doc:DiscriminatedUnions> instead. `@Extends` is for structural composition (always has both sets of fields), not for choice.
