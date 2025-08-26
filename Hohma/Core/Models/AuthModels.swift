//
//  TrpcResponse.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//
import Foundation

struct TrpcResponse: Decodable {
    struct Data: Decodable {
        struct JSON: Decodable {
            let user: AuthUser
            let success: Bool
            let token: String
        }
        let json: JSON
    }
    let data: Data
}

struct ResponseRoot: Decodable {
    let result: TrpcResponse
}

struct AuthResult: Codable {
    var user: AuthUser
    let token: String
}

// Структура для пустого ответа от tRPC
struct EmptyResponse: Codable {}
