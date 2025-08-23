//
//  NetworkManager.swift
//  Hohma
//
//  Created by Artem Vydro on 07.08.2025.
//

import Foundation

@MainActor
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

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            #if DEBUG
                print("🔐 NetworkManager: Received 401 error, logging out user")
            #endif
            // Уведомляем об ошибке авторизации через NotificationCenter
            NotificationCenter.default.post(name: .socketAuthorizationError, object: nil)
            // Даем небольшую задержку для корректного отключения сокета
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
                self.authViewModel?.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        // Проверяем другие ошибки HTTP
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            #if DEBUG
                print("❌ NetworkManager: HTTP error \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ NetworkManager: Error response body: \(responseString)")
                }
            #endif

            // Пытаемся извлечь сообщение об ошибке из tRPC ответа
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let error = json["error"] as? [String: Any],
                let message = error["message"] as? String
            {
                throw NSError(
                    domain: "NetworkError", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message])
            } else {
                // Создаем более информативную ошибку
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(
                    domain: "NetworkError", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
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
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #if DEBUG
                    print("🔍 NetworkManager: Response is valid JSON object")
                #endif
                #if DEBUG
                    print("🔍 NetworkManager: Response JSON structure: \(json)")
                #endif

                // Проверяем разные форматы tRPC ответов
                if let result = json["result"] as? [String: Any],
                    let resultData = result["data"] as? [String: Any],
                    let jsonData = resultData["json"]
                {
                    // Это tRPC ответ с оберткой result.data.json
                    #if DEBUG
                        print(
                            "🔍 NetworkManager: Extracted tRPC data from result.data.json: \(jsonData)"
                        )
                    #endif

                    // Проверяем, что jsonData не null и является валидным JSON объектом
                    if jsonData is NSNull {
                        // Если jsonData равен null, создаем пустые данные
                        let emptyData = Data()
                        return try customDecoder.decode(T.self, from: emptyData)
                    } else if let jsonObject = jsonData as? [String: Any] {
                        // Если это словарь, сериализуем его
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: jsonObject)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    } else if let jsonArray = jsonData as? [Any] {
                        // Если это массив, сериализуем его
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: jsonArray)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    } else {
                        // Если это примитив (строка, число, булево), создаем простой JSON
                        let simpleJson = ["value": jsonData]
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: simpleJson)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    }
                } else if let result = json["result"] {
                    // Это tRPC ответ с прямым result
                    #if DEBUG
                        print("🔍 NetworkManager: Extracted tRPC data from result: \(result)")
                    #endif

                    // Проверяем, что result не null
                    if result is NSNull {
                        let emptyData = Data()
                        return try customDecoder.decode(T.self, from: emptyData)
                    } else if let resultObject = result as? [String: Any] {
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: resultObject)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    } else if let resultArray = result as? [Any] {
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: resultArray)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    } else {
                        let simpleJson = ["value": result]
                        let jsonDataBytes = try JSONSerialization.data(withJSONObject: simpleJson)
                        return try customDecoder.decode(T.self, from: jsonDataBytes)
                    }
                }
            }

            // Если это не tRPC ответ, пробуем декодировать как есть
            #if DEBUG
                print("🔍 NetworkManager: Attempting to decode response as direct JSON")
            #endif
            return try customDecoder.decode(T.self, from: data)
        }
    }

    func setAuthViewModel(_ authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
}
