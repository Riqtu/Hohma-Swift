//
//  TelegramAuthResponse.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Foundation

struct TelegramAuthResponse: Codable {
    let id: Int
    let username: String
    let first_name: String
    let last_name: String?
    let photo_url: String?
    let auth_date: Int
    let hash: String
}
