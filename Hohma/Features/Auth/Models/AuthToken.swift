//
//  AuthToken.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Foundation

struct AuthToken: Codable {
    let token: String
    let expiresAt: Date?
}
