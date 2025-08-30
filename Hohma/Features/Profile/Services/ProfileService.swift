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

        // tRPC expects input to be wrapped in a json object for GET requests
        let trpcInput: [String: Any] = ["json": input]
        let inputJSONData = try JSONSerialization.data(withJSONObject: trpcInput)
        let inputString = String(data: inputJSONData, encoding: .utf8)!

        let response: BooleanResponse = try await trpcService.executeGET(
            endpoint: "subscription.isFollowing?input=\(inputString)"
        )

        return response.value
    }

    func getFollowing(userId: String? = nil) async throws -> [UserProfile] {
        let input: [String: Any] = userId != nil ? ["userId": userId!] : [:]

        // tRPC expects input to be wrapped in a json object for GET requests
        let trpcInput: [String: Any] = ["json": input]
        let inputJSONData = try JSONSerialization.data(withJSONObject: trpcInput)
        let inputString = String(data: inputJSONData, encoding: .utf8)!

        return try await trpcService.executeGET(
            endpoint: "subscription.getFollowing?input=\(inputString)"
        )
    }

    func getFollowers(userId: String? = nil) async throws -> [UserProfile] {
        let input: [String: Any] = userId != nil ? ["userId": userId!] : [:]

        // tRPC expects input to be wrapped in a json object for GET requests
        let trpcInput: [String: Any] = ["json": input]
        let inputJSONData = try JSONSerialization.data(withJSONObject: trpcInput)
        let inputString = String(data: inputJSONData, encoding: .utf8)!

        return try await trpcService.executeGET(
            endpoint: "subscription.getFollowers?input=\(inputString)"
        )
    }

    // MARK: - User Search

    func searchUsers(query: String, limit: Int = 20) async throws -> [UserProfile] {
        let input: [String: Any] = [
            "query": query,
            "limit": limit,
        ]

        // tRPC expects input to be wrapped in a json object for GET requests
        let trpcInput: [String: Any] = ["json": input]
        let inputJSONData = try JSONSerialization.data(withJSONObject: trpcInput)
        let inputString = String(data: inputJSONData, encoding: .utf8)!

        return try await trpcService.executeGET(
            endpoint: "user.search?input=\(inputString)"
        )
    }
}
