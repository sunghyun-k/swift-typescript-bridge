// ExtendsHierarchy.swift
//
// Demonstrates @Extends for flat JSON and property forwarding.
//
//   interface Identified  { id: string }
//   interface Timestamped { createdAt: number; updatedAt: number }
//   interface Article extends Identified, Timestamped {
//       title: string;
//       body: string;
//   }

import Foundation
import TypeScriptBridge

struct ExtendsIdentified: Codable {
    var id: String
}

struct ExtendsTimestamped: Codable {
    var createdAt: Double
    var updatedAt: Double
}

@Extends(ExtendsIdentified.self, ExtendsTimestamped.self)
struct ExtendsArticle {
    var title: String
    var body: String
}

enum ExtendsExample {
    static func demo() throws {
        let article = ExtendsArticle(
            ExtendsIdentified(id: "a-1"),
            ExtendsTimestamped(createdAt: 1_700_000_000, updatedAt: 1_700_000_100),
            title: "Hello",
            body: "World"
        )

        // Forwarding works for both parents:
        _ = article.id
        _ = article.createdAt
        _ = article.title

        // Flat JSON:
        let data = try JSONEncoder().encode(article)
        print(String(data: data, encoding: .utf8)!)

        let decoded = try JSONDecoder().decode(ExtendsArticle.self, from: data)
        precondition(decoded.id == "a-1")
        precondition(decoded.title == "Hello")
    }
}
