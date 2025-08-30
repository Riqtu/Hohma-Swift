//
//  SubscriptionViewModel.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Foundation
import SwiftUI

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var following: [UserProfile] = []
    @Published var followers: [UserProfile] = []
    @Published var searchResults: [UserProfile] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isSearching = false
    @Published var error: String?
    @Published var searchQuery = ""

    private let service = ProfileService.shared
    private var searchTask: Task<Void, Never>?

    // MARK: - Following Management

    func loadFollowing(userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let users = try await service.getFollowing(userId: userId)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.following = users
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadFollowers(userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let users = try await service.getFollowers(userId: userId)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.followers = users
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshFollowing(userId: String? = nil) async {
        isRefreshing = true
        defer { isRefreshing = false }

        await loadFollowing(userId: userId)
    }

    func refreshFollowers(userId: String? = nil) async {
        isRefreshing = true
        defer { isRefreshing = false }

        await loadFollowers(userId: userId)
    }

    // MARK: - User Search

    func searchUsers(query: String) async {
        // Отменяем предыдущий поиск
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            await MainActor.run {
                isSearching = true
                error = nil
            }

            do {
                let results = try await service.searchUsers(query: query, limit: 20)

                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.searchResults = results
                    }
                    isSearching = false
                }
            } catch {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }

                await MainActor.run {
                    self.error = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        searchQuery = ""
        error = nil
    }

    // MARK: - Follow/Unfollow Operations

    func followUser(followingId: String) async -> Bool {
        do {
            _ = try await service.followUser(followingId: followingId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func unfollowUser(followingId: String) async -> Bool {
        do {
            try await service.unfollowUser(followingId: followingId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func isFollowing(followingId: String) async -> Bool {
        do {
            return try await service.isFollowing(followingId: followingId)
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Clear Error
    func clearError() {
        error = nil
    }
}
