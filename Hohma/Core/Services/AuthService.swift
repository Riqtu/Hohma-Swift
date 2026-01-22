//
//  AuthService.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Foundation

final class AuthService {
    static let shared = AuthService()
    private init() {}

    func loginWithTelegramToken(_ token: String) async throws -> AuthResult {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/auth.telegramLogin")
        else {
            throw AppError.networkError("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var base64 = token
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let base64Data = Data(base64Encoded: base64) else {
            throw AppError.dataError("Base64 decode error")
        }

        guard let decodedString = String(data: base64Data, encoding: .utf8) else {
            throw AppError.dataError("String decode error")
        }

        // Попробуем распарсить как JSON
        guard let inputJsonData = decodedString.data(using: .utf8),
            let inputJson = try? JSONSerialization.jsonObject(with: inputJsonData) as? [String: Any]
        else {
            throw AppError.dataError("JSON decode error")
        }

        var fixedInputJson = inputJson
        fixedInputJson["id"] = String(describing: inputJson["id"] ?? "")
        fixedInputJson["auth_date"] = String(describing: inputJson["auth_date"] ?? "")
        fixedInputJson["hash"] = String(describing: inputJson["hash"] ?? "")

        let body = ["json": fixedInputJson]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
        }

        let decoded = try JSONDecoder().decode(ResponseRoot.self, from: data)
        let user = decoded.result.data.json.user
        let token = decoded.result.data.json.token
        let authResult = AuthResult(user: user, token: token)

        // Сохраняем в Keychain вместо UserDefaults
        do {
            try KeychainService.shared.saveAuthResult(authResult)
        } catch {
            AppLogger.shared.error(
                "Failed to save authResult to Keychain", error: error, category: .auth)
            // Продолжаем выполнение даже если сохранение не удалось
        }

        return authResult
    }

    func loginWithApple(_ request: AppleAuthRequest) async throws -> AuthResult {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/auth.appleLogin")
        else {
            throw AppError.networkError("Invalid API URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Сначала кодируем AppleAuthRequest в JSON
        guard let requestData = try? JSONEncoder().encode(request),
            let requestDict = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        else {
            throw AppError.dataError("JSON encoding error")
        }

        let body = ["json": requestDict]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse {
            AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
            
            // Проверяем статус ответа
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                throw AppError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        let decoded = try JSONDecoder().decode(ResponseRoot.self, from: data)
        let user = decoded.result.data.json.user
        let token = decoded.result.data.json.token
        let authResult = AuthResult(user: user, token: token)

        // Сохраняем в Keychain вместо UserDefaults
        do {
            try KeychainService.shared.saveAuthResult(authResult)
        } catch {
            AppLogger.shared.error(
                "Failed to save authResult to Keychain", error: error, category: .auth)
            // Продолжаем выполнение даже если сохранение не удалось
        }

        return authResult
    }

    func loginWithCredentials(
        username: String,
        password: String
    ) async throws -> AuthResult {
        let payload: [String: Any] = [
            "username": username,
            "password": password,
        ]

        return try await performCredentialsRequest(
            endpoint: "auth.login",
            payload: payload
        )
    }

    func registerWithCredentials(
        username: String,
        password: String,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> AuthResult {
        var payload: [String: Any] = [
            "username": username,
            "password": password,
        ]

        if let email, !email.isEmpty {
            payload["email"] = email
        }
        if let firstName, !firstName.isEmpty {
            payload["firstName"] = firstName
        }
        if let lastName, !lastName.isEmpty {
            payload["lastName"] = lastName
        }

        return try await performCredentialsRequest(
            endpoint: "auth.register",
            payload: payload
        )
    }

    private func performCredentialsRequest(
        endpoint: String,
        payload: [String: Any]
    ) async throws -> AuthResult {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/\(endpoint)")
        else {
            throw AppError.networkError("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["json": payload]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                throw AppError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        let decoded = try JSONDecoder().decode(ResponseRoot.self, from: data)
        let user = decoded.result.data.json.user
        let token = decoded.result.data.json.token
        let authResult = AuthResult(user: user, token: token)

        // Сохраняем в Keychain вместо UserDefaults
        do {
            try KeychainService.shared.saveAuthResult(authResult)
        } catch {
            AppLogger.shared.error(
                "Failed to save authResult to Keychain", error: error, category: .auth)
            // Продолжаем выполнение даже если сохранение не удалось
        }

        return authResult
    }
}
