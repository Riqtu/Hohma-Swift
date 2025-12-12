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

    func loginWithTelegramToken(
        _ token: String, completion: @escaping (Result<AuthResult, Error>) -> Void
    ) {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/auth.telegramLogin")
        else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var base64 = token
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            completion(.failure(NSError(domain: "Base64 decode error", code: -2)))
            return
        }

        guard let decodedString = String(data: data, encoding: .utf8) else {
            completion(.failure(NSError(domain: "String decode error", code: -3)))
            return
        }

        // Попробуем распарсить как JSON
        guard let inputJsonData = decodedString.data(using: .utf8),
            let inputJson = try? JSONSerialization.jsonObject(with: inputJsonData) as? [String: Any]
        else {
            completion(.failure(NSError(domain: "JSON decode error", code: -4)))
            return
        }

        var fixedInputJson = inputJson
        fixedInputJson["id"] = String(describing: inputJson["id"] ?? "")
        fixedInputJson["auth_date"] = String(describing: inputJson["auth_date"] ?? "")
        fixedInputJson["hash"] = String(describing: inputJson["hash"] ?? "")

        let body = ["json": fixedInputJson]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
            }

            do {
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

                completion(.success(authResult))
            } catch {
                AppLogger.shared.error("Auth decode error", error: error, category: .auth)
                completion(.failure(error))
            }
        }.resume()
    }

    func loginWithApple(
        _ request: AppleAuthRequest, completion: @escaping (Result<AuthResult, Error>) -> Void
    ) {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/auth.appleLogin")
        else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Сначала кодируем AppleAuthRequest в JSON
        guard let requestData = try? JSONEncoder().encode(request),
            let requestDict = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        else {
            completion(.failure(NSError(domain: "JSON encoding error", code: -1)))
            return
        }

        let body = ["json": requestDict]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
            }

            // Проверяем статус ответа
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                completion(
                    .failure(
                        NSError(
                            domain: "Server Error", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }

            do {
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

                completion(.success(authResult))
            } catch {
                AppLogger.shared.error("Apple auth decode error", error: error, category: .auth)
                completion(.failure(error))
            }
        }.resume()
    }

    func loginWithCredentials(
        username: String,
        password: String,
        completion: @escaping (Result<AuthResult, Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "username": username,
            "password": password,
        ]

        performCredentialsRequest(
            endpoint: "auth.login",
            payload: payload,
            completion: completion
        )
    }

    func registerWithCredentials(
        username: String,
        password: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        completion: @escaping (Result<AuthResult, Error>) -> Void
    ) {
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

        performCredentialsRequest(
            endpoint: "auth.register",
            payload: payload,
            completion: completion
        )
    }

    private func performCredentialsRequest(
        endpoint: String,
        payload: [String: Any],
        completion: @escaping (Result<AuthResult, Error>) -> Void
    ) {
        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/\(endpoint)")
        else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let body = ["json": payload]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.shared.logResponse(httpResponse, data: data, category: .auth)
            }

            if let httpResponse = response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode)
            {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                completion(
                    .failure(
                        NSError(
                            domain: "Server Error", code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }

            do {
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

                completion(.success(authResult))
            } catch {
                AppLogger.shared.error(
                    "Credentials auth decode error", error: error, category: .auth)
                completion(.failure(error))
            }
        }.resume()
    }
}
