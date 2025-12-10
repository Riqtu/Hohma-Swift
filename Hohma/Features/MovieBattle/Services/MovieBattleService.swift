//
//  MovieBattleService.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation

@MainActor
class MovieBattleService: ObservableObject, TRPCServiceProtocol {
    static let shared = MovieBattleService()
    private init() {}

    // MARK: - Battle Operations

    func createBattle(_ request: CreateMovieBattleRequest) async throws -> MovieBattle {
        return try await trpcService.executePOST(
            endpoint: "movieBattle.create",
            body: request.dictionary
        )
    }

    func getBattleById(
        id: String,
        includeMovies: Bool = true,
        includeParticipants: Bool = true,
        includeVotes: Bool = false
    ) async throws -> MovieBattle {
        let input: [String: Any] = [
            "id": id,
            "includeMovies": includeMovies,
            "includeParticipants": includeParticipants,
            "includeVotes": includeVotes,
        ]
        return try await trpcService.executeGET(
            endpoint: "movieBattle.getById",
            input: input
        )
    }

    func getBattles(
        status: MovieBattleStatus? = nil,
        isPrivate: Bool? = nil,
        creatorId: String? = nil,
        filterType: MovieBattleFilterType? = nil,
        limit: Int = 20,
        offset: Int = 0,
        includeMovies: Bool = true
    ) async throws -> [MovieBattle] {
        var input: [String: Any] = [
            "limit": limit,
            "offset": offset,
            "includeMovies": includeMovies,
        ]
        if let status = status {
            input["status"] = status.rawValue
        }
        if let isPrivate = isPrivate {
            input["isPrivate"] = isPrivate
        }
        if let creatorId = creatorId {
            input["creatorId"] = creatorId
        }
        if let filterType = filterType {
            input["filterType"] = filterType.rawValue
        }
        return try await trpcService.executeGET(
            endpoint: "movieBattle.getBattles",
            input: input
        )
    }

    func joinBattle(battleId: String) async throws -> MovieBattle {
        return try await trpcService.executePOST(
            endpoint: "movieBattle.join",
            body: ["battleId": battleId]
        )
    }

    func addMovie(_ request: AddMovieRequest) async throws -> MovieBattle {
        return try await trpcService.executePOST(
            endpoint: "movieBattle.addMovie",
            body: request.dictionary
        )
    }

    func startBattle(battleId: String) async throws -> MovieBattle {
        return try await trpcService.executePOST(
            endpoint: "movieBattle.start",
            body: ["battleId": battleId]
        )
    }

    func vote(_ request: VoteRequest) async throws -> MovieBattle {
        return try await trpcService.executePOST(
            endpoint: "movieBattle.vote",
            body: request.dictionary
        )
    }

    func deleteBattle(battleId: String) async throws {
        let _: EmptyResponse = try await trpcService.executePOST(
            endpoint: "movieBattle.delete",
            body: ["battleId": battleId]
        )
    }

    // MARK: - Socket URL
    func getSocketURL() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "WS_URL") as? String
            ?? "https://ws.hohma.su"
    }
}

// MARK: - Dictionary Extensions

extension CreateMovieBattleRequest {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "minMovies": minMovies,
            "maxMovies": maxMovies,
            "minParticipants": minParticipants,
            "isPrivate": isPrivate,
        ]
        if let votingTimeSeconds = votingTimeSeconds {
            dict["votingTimeSeconds"] = votingTimeSeconds
        }
        return dict
    }
}

extension AddMovieRequest {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "battleId": battleId,
            "title": title,
        ]
        if let kinopoiskId = kinopoiskId {
            dict["kinopoiskId"] = kinopoiskId
        }
        if let description = description {
            dict["description"] = description
        }
        if let posterUrl = posterUrl {
            dict["posterUrl"] = posterUrl
        }
        return dict
    }
}

extension VoteRequest {
    var dictionary: [String: Any] {
        [
            "battleId": battleId,
            "movieCardId": movieCardId,
        ]
    }
}

