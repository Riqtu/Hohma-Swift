//
//  StatsModels.swift
//  Hohma
//
//  Created by Assistant on 27.11.2025.
//

import Foundation

// Импортируем UserProfile из Subscription
// UserProfile уже определен в Features/Profile/Models/Subscription.swift

// MARK: - Game Type
enum GameType: String, Codable, CaseIterable {
    case all = "all"
    case wheel = "wheel"
    case race = "race"
    case battle = "battle"

    var displayName: String {
        switch self {
        case .all:
            return "Все игры"
        case .wheel:
            return "Колесо фортуны"
        case .race:
            return "Скачки"
        case .battle:
            return "Тайный фильм"
        }
    }
}

// MARK: - Sort By
enum SortBy: String, Codable, CaseIterable {
    case wins = "wins"
    case participations = "participations"
    case winRate = "winRate"
    case totalPrize = "totalPrize"

    var displayName: String {
        switch self {
        case .wins:
            return "Побед"
        case .participations:
            return "Участий"
        case .winRate:
            return "Процент побед"
        case .totalPrize:
            return "Призы"
        }
    }
}

// MARK: - User Stats
struct UserStats: Codable {
    let wins: Int
    let participations: Int
    let winRate: Double
    let totalPrize: Int
}

// MARK: - Game Stats
struct GameStats: Codable {
    let all: UserStats
    let wheel: UserStats
    let race: UserStats
    let battle: UserStats
}

// MARK: - Leaderboard Entry
struct LeaderboardEntry: Codable, Identifiable {
    var id: String {
        return user.id
    }
    let user: UserProfile
    let stats: GameStats
    let currentStats: UserStats

    enum CodingKeys: String, CodingKey {
        case user
        case stats
        case currentStats
    }
}

// MARK: - Leaderboard Response
struct LeaderboardResponse: Codable {
    let leaderboard: [LeaderboardEntry]
    let total: Int
}

// MARK: - User Stats Response
struct UserStatsResponse: Codable {
    let user: UserProfile
    let stats: GameStats
    let currentStats: UserStats
}
