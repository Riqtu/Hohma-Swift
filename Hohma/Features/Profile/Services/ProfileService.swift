import Foundation

final class ProfileService {
    static let shared = ProfileService()
    private init() {}

    private let networkManager = NetworkManager.shared
    private let baseURL = "https://riqtu.ru/api/trpc"

    func getProfile() async throws -> AuthUser {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            throw NSError(
                domain: "AuthError", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Не авторизован"])
        }

        guard let url = URL(string: "\(baseURL)/user.getCurrentProfile") else {
            throw NSError(
                domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authResult.token)", forHTTPHeaderField: "Authorization")

        return try await networkManager.request(request)
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> AuthUser {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            throw NSError(
                domain: "AuthError", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Не авторизован"])
        }

        guard let url = URL(string: "\(baseURL)/user.update") else {
            throw NSError(
                domain: "URLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(authResult.token)", forHTTPHeaderField: "Authorization")

        // Формируем tRPC запрос в правильном формате
        let trpcBody = ["json": request.dictionary]
        guard let requestData = try? JSONSerialization.data(withJSONObject: trpcBody) else {
            throw NSError(
                domain: "JSONError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка кодирования запроса"])
        }

        urlRequest.httpBody = requestData

        return try await networkManager.request(urlRequest)
    }
}
