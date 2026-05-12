// ApiResponses.swift
//
// Modeling a typical REST/RPC response envelope that is either a success
// payload or an error body. Discriminated on `status`. Same shape AI APIs
// (Anthropic / OpenAI) use for streaming events.
//
// TypeScript:
//
//   interface Ok<T> { status: "ok"; data: T }
//   interface Err   { status: "error"; code: number; message: string }
//   type ApiResponse<T> = Ok<T> | Err;
//
// Swift macros can't generalize the success payload via a generic enum,
// so we instantiate per resource. The pattern is mechanical.

import Foundation
import TypeScriptBridge

struct ApiUser: Codable, Equatable {
    var id: String
    var name: String
}

@UnionDiscriminator("status")
struct ApiOkUser: Codable {
    @Union("ok") enum Status {}
    var status: Status
    var data: ApiUser
}

@UnionDiscriminator("status")
struct ApiError: Codable {
    @Union("error") enum Status {}
    var status: Status
    var code: Int
    var message: String
}

@Union(ApiOkUser.self, ApiError.self)
enum ApiUserResponse {}

enum ApiResponseExample {
    static func demo() throws {
        let okJSON = ##"{"status":"ok","data":{"id":"u1","name":"Alice"}}"##
        let errJSON = ##"{"status":"error","code":404,"message":"not found"}"##

        for line in [okJSON, errJSON] {
            switch try JSONDecoder().decode(ApiUserResponse.self, from: Data(line.utf8)) {
            case .apiOkUser(let ok): print("[ok]", ok.data)
            case .apiError(let e): print("[error]", e.code, e.message)
            }
        }
    }
}
