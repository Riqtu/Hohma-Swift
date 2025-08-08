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
    let username: String
    let firstName: String?
    let lastName: String?
    let avatarUrl: URL?
    let password: String?

    static let mock = AuthUser(
        id: "6804fc3fd253e514c3fb6ae0",
        email: nil,
        name: nil,
        coins: 9679,
        clicks: 0,
        createdAt: "2025-04-20T13:53:02.953Z",
        updatedAt: "2025-06-21T14:39:45.280Z",
        activeCharacterId: "68472ca4dfca0fda77fe815b",
        activeBackgroundId: "68472d75cb122154ae21fffc",
        activeSkinId: nil,
        role: "ADMIN",
        telegramId: "195282466",
        googleId: nil,
        githubId: nil,
        facebookId: nil,
        vkId: nil,
        twitterId: nil,
        linkedInId: nil,
        discordId: nil,
        username: "riqtu",
        firstName: "Artem",
        lastName: "Vydro",
        avatarUrl: URL(string: "https://t.me/i/userpic/320/kzsHie85_ysC5uLNAf_9AEsNL6a92L5UzNVOxiE09uE.jpg"),
        password: nil
    )
}
