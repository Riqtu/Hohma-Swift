//
//  RoomUser.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

// MARK: - Room User Model
struct RoomUser: Codable {
    let id: String
    let username: String
    let firstName: String?
    let lastName: String?
    let coins: Int
    let avatarUrl: String?
    let role: String

    // Опциональные поля, которые могут отсутствовать
    let email: String?
    let name: String?
    let clicks: Int?
    let createdAt: String?
    let updatedAt: String?
    let activeCharacterId: String?
    let activeBackgroundId: String?
    let activeSkinId: String?
    let telegramId: String?
    let googleId: String?
    let githubId: String?
    let facebookId: String?
    let vkId: String?
    let twitterId: String?
    let linkedInId: String?
    let discordId: String?
    let password: String?

    // Конвертер в AuthUser
    func toAuthUser() -> AuthUser {
        return AuthUser(
            id: id,
            email: email,
            name: name,
            coins: coins,
            clicks: clicks ?? 0,
            createdAt: createdAt ?? "",
            updatedAt: updatedAt ?? "",
            activeCharacterId: activeCharacterId,
            activeBackgroundId: activeBackgroundId,
            activeSkinId: activeSkinId,
            role: role,
            telegramId: telegramId,
            googleId: googleId,
            githubId: githubId,
            facebookId: facebookId,
            vkId: vkId,
            twitterId: twitterId,
            linkedInId: linkedInId,
            discordId: discordId,
            username: username,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl != nil ? URL(string: avatarUrl!) : nil,
            password: password
        )
    }
}
