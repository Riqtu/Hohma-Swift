//
//  FortuneWheelService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

@MainActor
class FortuneWheelService: ObservableObject {
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Wheel Operations

    func getWheelById(_ id: String) async throws -> WheelWithRelations {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/wheelList.getById")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id] as [String: Any])

        return try await networkManager.request(request)
    }

    func updateWheelStatus(_ id: String, status: WheelStatus) async throws -> Wheel {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/wheelList.update")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["id": id, "status": status.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await networkManager.request(request)
    }

    // MARK: - Sector Operations

    func updateSector(_ id: String, eliminated: Bool) async throws -> Sector {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/sector.update")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["id": id, "eliminated": eliminated]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await networkManager.request(request)
    }

    func createSector(_ sector: Sector) async throws -> Sector {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/sector.create")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(sector)

        return try await networkManager.request(request)
    }

    func deleteSector(_ id: String) async throws -> Sector {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/sector.delete")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["id": id]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await networkManager.request(request)
    }

    // MARK: - Bet Operations

    func payoutBets(wheelId: String, winningSectorId: String) async throws {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/bet.payoutBets")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "wheelId": wheelId,
            "winningSectorId": winningSectorId,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await networkManager.request(request)
    }

    // MARK: - User Operations

    func getUserById(_ id: String) async throws -> AuthUser {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/user.getById")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id] as [String: Any])

        return try await networkManager.request(request)
    }

    // MARK: - Socket Configuration

    func getSocketURL() -> String {
        // В реальном приложении это должно приходить с сервера
        return "https://ws.hohma.su"
    }
}

// MARK: - Empty Response
struct EmptyResponse: Codable {}
