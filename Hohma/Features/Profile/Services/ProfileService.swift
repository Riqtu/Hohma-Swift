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
}
