//
//  StatsViewModel.swift
//  Hohma
//
//  Created by Assistant on 27.11.2025.
//

import Combine
import Foundation

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var userStats: UserStatsResponse?
    @Published var isLoading: Bool = false
    @Published var isLoadingUserStats: Bool = false
    @Published var errorMessage: String?

    // Фильтры и сортировка
    @Published var selectedGameType: GameType = .all
    @Published var selectedSortBy: SortBy = .wins

    private let statsService = StatsService.shared

    // MARK: - Load Leaderboard
    func loadLeaderboard() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let response = try await statsService.getLeaderboard(
                    gameType: selectedGameType,
                    sortBy: selectedSortBy
                )
                self.leaderboard = response.leaderboard
            } catch {
                errorMessage = error.localizedDescription
                print("❌ StatsViewModel: Ошибка загрузки лидерборда: \(error)")
            }

            isLoading = false
        }
    }

    // MARK: - Load User Stats
    func loadUserStats(userId: String? = nil) {
        Task {
            isLoadingUserStats = true
            errorMessage = nil

            do {
                let stats = try await statsService.getUserStats(
                    userId: userId,
                    gameType: selectedGameType
                )
                self.userStats = stats
            } catch {
                errorMessage = error.localizedDescription
                print("❌ StatsViewModel: Ошибка загрузки статистики пользователя: \(error)")
            }

            isLoadingUserStats = false
        }
    }

    // MARK: - Apply Filters
    func applyFilters() {
        loadLeaderboard()
        if userStats != nil {
            loadUserStats()
        }
    }
}
