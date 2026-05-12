// Webhooks.swift
//
// A webhook receiver typically gets a payload tagged by `type`, where the
// tag value implies the rest of the body's shape. Discord / Slack / Stripe
// webhooks all follow this pattern.

import Foundation
import TypeScriptBridge

@UnionDiscriminator("type")
struct WebhookMessageCreated: Codable {
    @Union("message.created") enum Kind {}
    var type: Kind
    var channel: String
    var author: String
    var content: String
}

@UnionDiscriminator("type")
struct WebhookReactionAdded: Codable {
    @Union("reaction.added") enum Kind {}
    var type: Kind
    var channel: String
    var messageId: String
    var emoji: String
}

@UnionDiscriminator("type")
struct WebhookUserJoined: Codable {
    @Union("user.joined") enum Kind {}
    var type: Kind
    var user: String
}

@Union(WebhookMessageCreated.self, WebhookReactionAdded.self, WebhookUserJoined.self)
enum WebhookEvent {}

enum WebhookExample {
    static func demo() throws {
        let payloads = [
            ##"{"type":"message.created","channel":"#general","author":"alice","content":"hi"}"##,
            ##"{"type":"reaction.added","channel":"#general","messageId":"m-1","emoji":"🎉"}"##,
            ##"{"type":"user.joined","user":"bob"}"##,
        ]

        for p in payloads {
            switch try JSONDecoder().decode(WebhookEvent.self, from: Data(p.utf8)) {
            case .webhookMessageCreated(let m): print("msg:", m.author, m.content)
            case .webhookReactionAdded(let r): print("rxn:", r.emoji, "on", r.messageId)
            case .webhookUserJoined(let u): print("join:", u.user)
            }
        }
    }
}
