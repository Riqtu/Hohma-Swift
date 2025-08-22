//
//  AuthUser.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Foundation

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let coins: Int
    let clicks: Int
    let createdAt: String
    let updatedAt: String
    let activeCharacterId: String?
    let activeBackgroundId: String?
    let activeSkinId: String?
    let role: String
    let telegramId: String?
    let googleId: String?
    let githubId: String?
    let facebookId: String?
    let vkId: String?
    let twitterId: String?
    let linkedInId: String?
    let discordId: String?
    let appleId: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: URL?
    let password: String?

    static let mock = AuthUser(
        id: "mock_id",
        email: nil,
        name: nil,
        coins: 0,
        clicks: 0,
        createdAt: "2025-01-01T00:00:00.000Z",
        updatedAt: "2025-01-01T00:00:00.000Z",
        activeCharacterId: nil,
        activeBackgroundId: nil,
        activeSkinId: nil,
        role: "USER",
        telegramId: "mock_telegram_id",
        googleId: nil,
        githubId: nil,
        facebookId: nil,
        vkId: nil,
        twitterId: nil,
        linkedInId: nil,
        discordId: nil,
        appleId: nil,
        username: "mock_user",
        firstName: nil,
        lastName: nil,
        avatarUrl: nil,
        password: nil
    )
}
