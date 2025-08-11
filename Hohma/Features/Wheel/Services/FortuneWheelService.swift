//
//  FortuneWheelService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

class FortuneWheelService {
    private let networkManager: NetworkManager
    private let apiURL: String?

    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
        self.apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    }

    // MARK: - Wheel Operations

    func getWheel(id: String) async throws -> WheelWithRelations {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.getById") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["id": id])
        return try await networkManager.request(request)
    }

    func updateWheelStatus(id: String, status: WheelStatus) async throws -> Wheel {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.update") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "id": id,
            "status": status.rawValue,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await networkManager.request(request)
    }

    // MARK: - Sector Operations

    func updateSector(id: String, eliminated: Bool, winner: Bool = false) async throws -> Sector {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/sector.update") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "id": id,
            "eliminated": eliminated,
            "winner": winner,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await networkManager.request(request)
    }

    func createSector(wheelId: String, sectorData: CreateSectorData) async throws -> Sector {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/sector.create") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Добавляем wheelId к данным сектора
        var sectorDataWithWheelId = sectorData
        // Создаем новый объект с wheelId
        let body: [String: Any] = [
            "wheelId": wheelId,
            "label": sectorData.label,
            "name": sectorData.name,
            "color": sectorData.color,
            "description": sectorData.description,
            "pattern": sectorData.pattern,
            "patternPosition": sectorData.patternPosition,
            "poster": sectorData.poster,
            "genre": sectorData.genre,
            "rating": sectorData.rating,
            "year": sectorData.year,
            "labelColor": sectorData.labelColor,
            "labelHidden": sectorData.labelHidden,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await networkManager.request(request)
    }

    func deleteSector(id: String) async throws {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/sector.delete") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["id": id]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await networkManager.request(request)
    }

    // MARK: - Bet Operations

    func placeBet(wheelId: String, sectorId: String, amount: Int) async throws -> Bet {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/bet.placeBet") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "wheelId": wheelId,
            "sectorId": sectorId,
            "amount": amount,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await networkManager.request(request)
    }

    func payoutBets(wheelId: String, winningSectorId: String) async throws {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/bet.payoutBets") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "wheelId": wheelId,
            "winningSectorId": winningSectorId,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let _: EmptyResponse = try await networkManager.request(request)
    }

}

// MARK: - Data Models

struct CreateSectorData: Codable {
    let label: String
    let name: String
    let color: ColorJSON
    let description: String?
    let pattern: String?
    let patternPosition: PatternPositionJSON?
    let poster: String?
    let genre: String?
    let rating: String?
    let year: String?
    let labelColor: String?
    let labelHidden: Bool
}

struct EmptyResponse: Codable {}
