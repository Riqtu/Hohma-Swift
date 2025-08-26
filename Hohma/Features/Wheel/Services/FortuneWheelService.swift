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
    static let shared = FortuneWheelService()
    private init() {}

    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Получаем токен авторизации
    private var authToken: String? {
        if let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let savedAuthResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        {
            return savedAuthResult.token
        }
        return nil
    }

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
        let body = wrapInTRPCFormat(["id": id])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

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
        let body = wrapInTRPCFormat(["id": id, "status": status.rawValue])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

        return try await networkManager.request(request)
    }

    // MARK: - Sector Operations

    func updateSector(_ id: String, eliminated: Bool, winner: Bool? = nil) async throws -> Sector {
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

        var bodyData: [String: Any] = ["id": id, "eliminated": eliminated]
        if let winner = winner {
            bodyData["winner"] = winner
        }

        let body = wrapInTRPCFormat(bodyData)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

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
        let sectorData = try JSONEncoder().encode(sector)
        let sectorDict = try JSONSerialization.jsonObject(with: sectorData) as? [String: Any] ?? [:]
        let body = wrapInTRPCFormat(sectorDict)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

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
        let body = wrapInTRPCFormat(["id": id])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

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
        let body = wrapInTRPCFormat([
            "wheelId": wheelId,
            "winningSectorId": winningSectorId,
        ])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

        let _: SuccessResponse = try await networkManager.request(request)
    }

    // MARK: - Wheel Creation

    func createWheel(_ wheelRequest: WheelCreateRequest) async throws -> WheelWithRelations {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/wheelList.create")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = wrapInTRPCFormat(wheelRequest.dictionary)
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &urlRequest)

        return try await networkManager.request(urlRequest)
    }

    func getAllThemes() async throws -> [WheelTheme] {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/wheelTheme.getAllExpress")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthorizationHeader(to: &request)

        return try await networkManager.request(request)
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
        let body = wrapInTRPCFormat(["id": id])
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        addAuthorizationHeader(to: &request)

        return try await networkManager.request(request)
    }

    // MARK: - Private Methods

    private func addAuthorizationHeader(to request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            #if DEBUG
                print("🔐 FortuneWheelService: Added authorization token to request")
            #endif
        } else {
            #if DEBUG
                print("⚠️ FortuneWheelService: No authorization token available")
            #endif
        }

        #if DEBUG
            print("🔍 FortuneWheelService: Request URL: \(request.url?.absoluteString ?? "unknown")")
            print("🔍 FortuneWheelService: Request method: \(request.httpMethod ?? "unknown")")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("🔍 FortuneWheelService: Request body: \(bodyString)")
            }
        #endif
    }

    private func wrapInTRPCFormat(_ data: [String: Any]) -> [String: Any] {
        return ["json": data]
    }

    // MARK: - Socket Configuration

    func getSocketURL() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "WS_URL") as? String
            ?? "https://ws.hohma.su"
    }
}

// MARK: - Response Models
struct SuccessResponse: Codable {
    let success: Bool
}
