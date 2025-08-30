import Foundation

final class ProfileService: TRPCServiceProtocol {
    static let shared = ProfileService()
    private init() {}

    func getProfile() async throws -> AuthUser {
        return try await trpcService.executeGET(endpoint: "user.getCurrentProfile")
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> AuthUser {
        return try await trpcService.executePOST(endpoint: "user.update", body: request.dictionary)
    }

    func deleteAccount() async throws {
        let userId = try trpcService.getCurrentUserId()

        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "user.delete",
            body: ["id": userId]
        )
    }

    // MARK: - Subscription Operations

    func followUser(followingId: String) async throws -> Subscription {
        return try await trpcService.executePOST(
            endpoint: "subscription.follow",
            body: ["followingId": followingId]
        )
    }

    func unfollowUser(followingId: String) async throws {
        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "subscription.unfollow",
            body: ["followingId": followingId]
        )
    }

    func isFollowing(followingId: String) async throws -> Bool {
        let input: [String: Any] = ["followingId": followingId]
        let response: BooleanResponse = try await trpcService.executeGET(
            endpoint: "subscription.isFollowing",
            input: input
        )
        return response.value
    }

    func getFollowing(userId: String? = nil) async throws -> [UserProfile] {
        let input: [String: Any] = userId != nil ? ["userId": userId!] : [:]
        return try await trpcService.executeGET(
            endpoint: "subscription.getFollowing",
            input: input
        )
    }

    func getFollowers(userId: String? = nil) async throws -> [UserProfile] {
        let input: [String: Any] = userId != nil ? ["userId": userId!] : [:]
        return try await trpcService.executeGET(
            endpoint: "subscription.getFollowers",
            input: input
        )
    }

    // MARK: - User Search

    func searchUsers(query: String, limit: Int = 20) async throws -> [UserProfile] {
        let input: [String: Any] = [
            "query": query,
            "limit": limit,
        ]
        return try await trpcService.executeGET(
            endpoint: "user.search",
            input: input
        )
    }

    // MARK: - Other User Profile Operations

    func getUserProfile(userId: String) async throws -> UserProfile {
        let input: [String: Any] = ["id": userId]
        return try await trpcService.executeGET(
            endpoint: "user.getById",
            input: input
        )
    }

    func getUserWheels(userId: String) async throws -> [Wheel] {
        let input: [String: Any] = ["userId": userId]
        return try await trpcService.executeGET(
            endpoint: "wheelList.getByUserId",
            input: input
        )
    }
}
