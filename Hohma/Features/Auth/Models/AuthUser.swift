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
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        coins = try container.decode(Int.self, forKey: .coins)
        clicks = try container.decode(Int.self, forKey: .clicks)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        activeCharacterId = try container.decodeIfPresent(String.self, forKey: .activeCharacterId)
        activeBackgroundId = try container.decodeIfPresent(String.self, forKey: .activeBackgroundId)
        activeSkinId = try container.decodeIfPresent(String.self, forKey: .activeSkinId)
        role = try container.decode(String.self, forKey: .role)
        telegramId = try container.decodeIfPresent(String.self, forKey: .telegramId)
        googleId = try container.decodeIfPresent(String.self, forKey: .googleId)
        githubId = try container.decodeIfPresent(String.self, forKey: .githubId)
        facebookId = try container.decodeIfPresent(String.self, forKey: .facebookId)
        vkId = try container.decodeIfPresent(String.self, forKey: .vkId)
        twitterId = try container.decodeIfPresent(String.self, forKey: .twitterId)
        linkedInId = try container.decodeIfPresent(String.self, forKey: .linkedInId)
        discordId = try container.decodeIfPresent(String.self, forKey: .discordId)
        appleId = try container.decodeIfPresent(String.self, forKey: .appleId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        
        // Декодируем avatarUrl из строки в URL
        if let avatarUrlString = try container.decodeIfPresent(String.self, forKey: .avatarUrl),
           !avatarUrlString.isEmpty,
           avatarUrlString != "<null>",
           avatarUrlString.lowercased() != "null" {
            avatarUrl = URL(string: avatarUrlString)
        } else {
            avatarUrl = nil
        }
        
        password = try container.decodeIfPresent(String.self, forKey: .password)
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(coins, forKey: .coins)
        try container.encode(clicks, forKey: .clicks)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(activeCharacterId, forKey: .activeCharacterId)
        try container.encodeIfPresent(activeBackgroundId, forKey: .activeBackgroundId)
        try container.encodeIfPresent(activeSkinId, forKey: .activeSkinId)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(telegramId, forKey: .telegramId)
        try container.encodeIfPresent(googleId, forKey: .googleId)
        try container.encodeIfPresent(githubId, forKey: .githubId)
        try container.encodeIfPresent(facebookId, forKey: .facebookId)
        try container.encodeIfPresent(vkId, forKey: .vkId)
        try container.encodeIfPresent(twitterId, forKey: .twitterId)
        try container.encodeIfPresent(linkedInId, forKey: .linkedInId)
        try container.encodeIfPresent(discordId, forKey: .discordId)
        try container.encodeIfPresent(appleId, forKey: .appleId)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(avatarUrl?.absoluteString, forKey: .avatarUrl)
        try container.encodeIfPresent(password, forKey: .password)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, coins, clicks, createdAt, updatedAt
        case activeCharacterId, activeBackgroundId, activeSkinId
        case role, telegramId, googleId, githubId, facebookId
        case vkId, twitterId, linkedInId, discordId, appleId
        case username, firstName, lastName, avatarUrl, password
    }
    
    // MARK: - Initializer
    init(
        id: String,
        email: String?,
        name: String?,
        coins: Int,
        clicks: Int,
        createdAt: String,
        updatedAt: String,
        activeCharacterId: String?,
        activeBackgroundId: String?,
        activeSkinId: String?,
        role: String,
        telegramId: String?,
        googleId: String?,
        githubId: String?,
        facebookId: String?,
        vkId: String?,
        twitterId: String?,
        linkedInId: String?,
        discordId: String?,
        appleId: String?,
        username: String?,
        firstName: String?,
        lastName: String?,
        avatarUrl: URL?,
        password: String?
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.coins = coins
        self.clicks = clicks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activeCharacterId = activeCharacterId
        self.activeBackgroundId = activeBackgroundId
        self.activeSkinId = activeSkinId
        self.role = role
        self.telegramId = telegramId
        self.googleId = googleId
        self.githubId = githubId
        self.facebookId = facebookId
        self.vkId = vkId
        self.twitterId = twitterId
        self.linkedInId = linkedInId
        self.discordId = discordId
        self.appleId = appleId
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.password = password
    }

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
