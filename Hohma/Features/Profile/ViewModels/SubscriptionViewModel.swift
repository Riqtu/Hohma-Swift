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
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String?

    private let service = ProfileService.shared

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
