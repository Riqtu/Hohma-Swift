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

    func loginWithTelegramToken(_ token: String, completion: @escaping (Result<AuthResult, Error>) -> Void) {
        guard let url = URL(string: "https://riqtu.ru/api/trpc/auth.telegramLogin") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        print(url)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        print("TOKEN:\n\(token)")
        var base64 = token
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else {
            print("Ошибка декодирования base64")
            completion(.failure(NSError(domain: "Base64 decode error", code: -2)))
            return
        }
        guard let decodedString = String(data: data, encoding: .utf8) else {
            print("Не удалось преобразовать Data в String")
            completion(.failure(NSError(domain: "String decode error", code: -3)))
            return
        }
        print("Расшифрованная строка:\n\(decodedString)")
        // Попробуем распарсить как JSON
        guard let inputJsonData = decodedString.data(using: .utf8),
              let inputJson = try? JSONSerialization.jsonObject(with: inputJsonData) as? [String: Any] else {
            print("Не удалось распарсить строку как JSON-словарь")
            completion(.failure(NSError(domain: "JSON decode error", code: -4)))
            return
        }
        var fixedInputJson = inputJson
        fixedInputJson["id"] = String(describing: inputJson["id"] ?? "")
        fixedInputJson["auth_date"] = String(describing: inputJson["auth_date"] ?? "")
        fixedInputJson["hash"] = String(describing: inputJson["hash"] ?? "")
        let body =  ["json": fixedInputJson]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted) {
            // Красиво вывести JSON-строку в консоль:
            if let bodyString = String(data: bodyData, encoding: .utf8) {
                print("BODY:\n\(bodyString)")
            }
            request.httpBody = bodyData
        } else {
            print("Ошибка сериализации body")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("inputJson type:", type(of: inputJson))
        print("inputJson:", inputJson)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            print("RESPONSE:", response ?? "nil")
            print("DATA:", String(data: data, encoding: .utf8) ?? "nil")
            do {
                let decoded = try JSONDecoder().decode(ResponseRoot.self, from: data)
                let user = decoded.result.data.json.user
                let token = decoded.result.data.json.token
                let authResult = AuthResult(user: user, token: token)
                if let authResultData = try? JSONEncoder().encode(authResult) {
                    UserDefaults.standard.set(authResultData, forKey: "authResult")
                }
                completion(.success(authResult))
            } catch {
                print(error)
                completion(.failure(error))
            }
        }.resume()
    }
}
