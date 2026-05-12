// AnalyticsEvents.swift
//
// Real-world pattern: a single endpoint receives heterogeneous analytics
// events from a TypeScript front-end. Each event carries an `event` tag
// that picks the variant.
//
// TypeScript:
//
//   interface PageViewEvent { event: "page_view"; page: string; referrer?: string }
//   interface ClickEvent    { event: "click"; element: string; coords: { x: number; y: number } }
//   interface ErrorEvent    { event: "error"; code: number; message: string }
//   type AnalyticsEvent = PageViewEvent | ClickEvent | ErrorEvent;

import Foundation
import TypeScriptBridge

@UnionDiscriminator("event")
struct AnalyticsPageView: Codable {
    @Union("page_view") enum EventTag {}
    var event: EventTag
    var page: String
    var referrer: String?
}

@UnionDiscriminator("event")
struct AnalyticsClick: Codable {
    @Union("click") enum EventTag {}
    var event: EventTag
    var element: String
    var coords: AnalyticsCoords
}

struct AnalyticsCoords: Codable {
    var x: Int
    var y: Int
}

@UnionDiscriminator("event")
struct AnalyticsErrorOccurred: Codable {
    @Union("error") enum EventTag {}
    var event: EventTag
    var code: Int
    var message: String
}

@Union(AnalyticsPageView.self, AnalyticsClick.self, AnalyticsErrorOccurred.self)
enum AnalyticsAnyEvent {}

enum AnalyticsExample {
    static func demo() throws {
        let jsonLines = [
            ##"{"event":"page_view","page":"/home"}"##,
            ##"{"event":"click","element":"#cta","coords":{"x":12,"y":34}}"##,
            ##"{"event":"error","code":500,"message":"boom"}"##,
        ]

        for line in jsonLines {
            let event = try JSONDecoder().decode(AnalyticsAnyEvent.self, from: Data(line.utf8))
            switch event {
            case .analyticsPageView(let p): print("[pageview]", p.page)
            case .analyticsClick(let c): print("[click]", c.element, c.coords.x, c.coords.y)
            case .analyticsErrorOccurred(let e): print("[error]", e.code, e.message)
            }
        }
    }
}
