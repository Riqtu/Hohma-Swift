//
//  AppleAuthResponse.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

struct AppleAuthResponse: Codable {
    let success: Bool
    let user: AuthUser
    let token: String
}

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String?
    let user: AppleUser?
}

struct AppleUser: Codable {
    let email: String?
    let name: AppleUserName?
}

struct AppleUserName: Codable {
    let firstName: String?
    let lastName: String?
}
