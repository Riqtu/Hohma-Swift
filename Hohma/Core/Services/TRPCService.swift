import Foundation

// MARK: - TRPC Service Protocol
protocol TRPCServiceProtocol {
    var trpcService: TRPCService { get }
}

extension TRPCServiceProtocol {
    var trpcService: TRPCService {
        return TRPCService.shared
    }
}

// MARK: - Base TRPC Service
class TRPCService {
    static let shared = TRPCService()
    private init() {}

    @MainActor
    private var networkManager: NetworkManager {
        NetworkManager.shared
    }

    // MARK: - Base URL
    var baseURL: String {
        return Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
            ?? "https://hohma.su/api/trpc"
    }

    // MARK: - Auth Token Management
    var authToken: String? {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            return nil
        }
        return authResult.token
    }

    var currentUser: AuthUser? {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            return nil
        }
        return authResult.user
    }

    func getCurrentUserId() throws -> String {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            throw NetworkError.unauthorized
        }
        return authResult.user.id
    }

    // MARK: - Request Builders
    func createGETRequest(endpoint: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthorizationHeader(to: &request)
        return request
    }

    func createPOSTRequest<T: Encodable>(endpoint: String, body: T) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthorizationHeader(to: &request)

        // Wrap in tRPC format
        let trpcBody = ["json": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: trpcBody)

        return request
    }

    func createPOSTRequest(endpoint: String, body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthorizationHeader(to: &request)

        // Wrap in tRPC format
        let trpcBody = ["json": body]
        request.httpBody = try JSONSerialization.data(withJSONObject: trpcBody)

        return request
    }

    // MARK: - Request Execution
    @MainActor
    func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        return try await networkManager.request(request)
    }

    @MainActor
    func executeGET<T: Decodable>(endpoint: String) async throws -> T {
        let request = try createGETRequest(endpoint: endpoint)
        return try await execute(request)
    }

    /// Выполняет GET запрос к tRPC endpoint с параметрами
    /// - Parameters:
    ///   - endpoint: tRPC endpoint (например, "user.search")
    ///   - input: Параметры запроса в виде словаря
    /// - Returns: Декодированный ответ указанного типа
    /// - Throws: NetworkError при ошибках сети или авторизации
    @MainActor
    func executeGET<T: Decodable>(endpoint: String, input: [String: Any]) async throws -> T {
        // tRPC expects input to be wrapped in a json object for GET requests
        let trpcInput: [String: Any] = ["json": input]
        let inputJSONData = try JSONSerialization.data(withJSONObject: trpcInput)
        let inputString = String(data: inputJSONData, encoding: .utf8)!

        let request = try createGETRequest(endpoint: "\(endpoint)?input=\(inputString)")
        return try await execute(request)
    }

    @MainActor
    func executePOST<T: Decodable, U: Encodable>(endpoint: String, body: U) async throws -> T {
        let request = try createPOSTRequest(endpoint: endpoint, body: body)
        return try await execute(request)
    }

    @MainActor
    func executePOST<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        let request = try createPOSTRequest(endpoint: endpoint, body: body)
        return try await execute(request)
    }

    // MARK: - Private Methods
    private func addAuthorizationHeader(to request: inout URLRequest) throws {
        guard let token = authToken else {
            throw NetworkError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case unauthorized
    case encodingError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .unauthorized:
            return "Не авторизован"
        case .encodingError:
            return "Ошибка кодирования запроса"
        case .decodingError:
            return "Ошибка декодирования ответа"
        }
    }
}
