//
//  StatsService.swift
//  Hohma
//
//  Created by Assistant on 27.11.2025.
//

import Foundation

final class StatsService: TRPCServiceProtocol {
    static let shared = StatsService()
    private init() {}
    
    // MARK: - Get Leaderboard
    func getLeaderboard(
        gameType: GameType = .all,
        sortBy: SortBy = .wins,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> LeaderboardResponse {
        let input: [String: Any] = [
            "gameType": gameType.rawValue,
            "sortBy": sortBy.rawValue,
            "limit": limit,
            "offset": offset,
        ]
        return try await trpcService.executeGET(
            endpoint: "stats.getLeaderboard",
            input: input
        )
    }
    
    // MARK: - Get User Stats
    func getUserStats(
        userId: String? = nil,
        gameType: GameType = .all
    ) async throws -> UserStatsResponse {
        var input: [String: Any] = [
            "gameType": gameType.rawValue,
        ]
        if let userId = userId {
            input["userId"] = userId
        }
        return try await trpcService.executeGET(
            endpoint: "stats.getUserStats",
            input: input
        )
    }
}

