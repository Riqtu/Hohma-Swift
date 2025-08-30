//
//  FortuneWheelService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

@MainActor
class FortuneWheelService: ObservableObject, TRPCServiceProtocol {
    static let shared = FortuneWheelService()
    private init() {}

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Wheel Operations

    func getWheelById(_ id: String) async throws -> WheelWithRelations {
        return try await trpcService.executePOST(endpoint: "wheelList.getById", body: ["id": id])
    }

    func updateWheelStatus(_ id: String, status: WheelStatus) async throws -> Wheel {
        return try await trpcService.executePOST(
            endpoint: "wheelList.update",
            body: ["id": id, "status": status.rawValue]
        )
    }

    func updateWheel(_ wheelRequest: WheelUpdateRequest) async throws -> WheelWithRelations {
        return try await trpcService.executePOST(
            endpoint: "wheelList.update",
            body: wheelRequest.dictionary
        )
    }

    // MARK: - Sector Operations

    func updateSector(_ id: String, eliminated: Bool, winner: Bool? = nil) async throws -> Sector {
        var bodyData: [String: Any] = ["id": id, "eliminated": eliminated]
        if let winner = winner {
            bodyData["winner"] = winner
        }

        return try await trpcService.executePOST(endpoint: "sector.update", body: bodyData)
    }

    func createSector(_ sector: Sector) async throws -> Sector {
        return try await trpcService.executePOST(endpoint: "sector.create", body: sector.dictionary)
    }

    func deleteSector(_ id: String) async throws {
        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "sector.delete",
            body: ["id": id]
        )
    }

    // MARK: - Bet Operations

    func placeBet(wheelId: String, sectorId: String, amount: Int) async throws -> Bet {
        return try await trpcService.executePOST(
            endpoint: "bet.placeBet",
            body: [
                "wheelId": wheelId,
                "sectorId": sectorId,
                "amount": amount,
            ]
        )
    }

    func getBets(wheelId: String) async throws -> [Bet] {
        return try await trpcService.executePOST(
            endpoint: "bet.getBets",
            body: ["wheelId": wheelId]
        )
    }

    func payoutBets(wheelId: String, winningSectorId: String) async throws {
        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "bet.payoutBets",
            body: [
                "wheelId": wheelId,
                "winningSectorId": winningSectorId,
            ]
        )
    }

    // MARK: - Wheel Creation

    func createWheel(_ wheelRequest: WheelCreateRequest) async throws -> WheelWithRelations {
        return try await trpcService.executePOST(
            endpoint: "wheelList.create", body: wheelRequest.dictionary)
    }

    func getAllThemes() async throws -> [WheelTheme] {
        return try await trpcService.executeGET(endpoint: "wheelTheme.getAllExpress")
    }

    // MARK: - Wheel List with Filters

    func getWheelsWithPagination(page: Int = 1, limit: Int = 20, filter: WheelFilter? = nil)
        async throws -> WheelListPaginationContent
    {
        let input: [String: Any] = [
            "page": page,
            "limit": limit,
            "filter": filter?.rawValue ?? "all",
        ]
        return try await trpcService.executeGET(
            endpoint: "wheelList.getAllWithPagination",
            input: input
        )
    }

    // MARK: - Wheel Deletion

    func deleteWheel(id: String) async throws -> Wheel {
        let response: WheelDeleteResponse = try await trpcService.executePOST(
            endpoint: "wheelList.delete",
            body: ["id": id]
        )
        return response.result.data.json
    }

    // MARK: - Socket URL
    func getSocketURL() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "WS_URL") as? String
            ?? "https://ws.hohma.su"
    }
}
