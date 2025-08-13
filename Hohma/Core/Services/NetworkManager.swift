//
//  NetworkManager.swift
//  Hohma
//
//  Created by Artem Vydro on 07.08.2025.
//

import Foundation

final class NetworkManager {
    static let shared = NetworkManager()
    var authViewModel: AuthViewModel?

    func request<T: Decodable>(_ endpoint: URLRequest, decoder: JSONDecoder = .init()) async throws
        -> T
    {
        // Настраиваем decoder для правильного декодирования дат
        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = .iso8601withMilliseconds

        let (data, response) = try await URLSession.shared.data(for: endpoint)

        #if DEBUG
            // Логируем ответ сервера для отладки
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 NetworkManager: Response status: \(httpResponse.statusCode)")
                print("🔍 NetworkManager: Response headers: \(httpResponse.allHeaderFields)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 NetworkManager: Response body: \(responseString)")
            }
        #endif

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            #if DEBUG
                print("🔐 NetworkManager: Received 401 error, logging out user")
            #endif
            // Уведомляем об ошибке авторизации через NotificationCenter
            await MainActor.run {
                NotificationCenter.default.post(name: .socketAuthorizationError, object: nil)
                // Даем небольшую задержку для корректного отключения сокета
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.authViewModel?.logout()
                }
            }
            throw URLError(.userAuthenticationRequired)
        }

        // Проверяем другие ошибки HTTP
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            #if DEBUG
                print("❌ NetworkManager: HTTP error \(httpResponse.statusCode)")
            #endif
            throw URLError(.badServerResponse)
        }

        // Пытаемся декодировать как tRPC ответ
        do {
            return try customDecoder.decode(T.self, from: data)
        } catch {
            // Если не получилось, возможно это tRPC ответ с оберткой
            #if DEBUG
                print("🔍 NetworkManager: Trying to decode as tRPC response")
            #endif

            // Проверяем, не является ли это tRPC ответом
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let result = json["result"] as? [String: Any],
                let resultData = result["data"] as? [String: Any],
                let jsonData = resultData["json"]
            {
                // Это tRPC ответ, извлекаем данные из result.data.json
                #if DEBUG
                    print("🔍 NetworkManager: Extracted tRPC data: \(jsonData)")
                #endif
                let jsonDataBytes = try JSONSerialization.data(withJSONObject: jsonData)
                return try customDecoder.decode(T.self, from: jsonDataBytes)
            }

            // Если это не tRPC ответ, пробуем декодировать как есть
            return try customDecoder.decode(T.self, from: data)
        }
    }

    func setAuthViewModel(_ authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
}
