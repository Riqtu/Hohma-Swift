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

    // MARK: - Properties
    private var authViewModel: AuthViewModel?
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601withMilliseconds
    }

    // MARK: - Public Methods
    func request<T: Decodable>(_ endpoint: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: endpoint)

            // Handle HTTP errors
            try handleHTTPErrors(data: data, response: response)

            // Decode response
            return try decodeResponse(data: data, as: T.self)

        } catch {
            #if DEBUG
                print("❌ NetworkManager: Request failed with error: \(error)")
            #endif
            throw error
        }
    }

    func setAuthViewModel(_ authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: - Private Methods
    private func handleHTTPErrors(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 401:
            handleUnauthorizedError()
            throw NetworkError.unauthorized

        case 400...599:
            let errorMessage = extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw AppError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")

        default:
            break
        }
    }

    private func handleUnauthorizedError() {
        #if DEBUG
            print("🔐 NetworkManager: Received 401 error, logging out user")
        #endif

        NotificationCenter.default.post(name: .socketAuthorizationError, object: nil)

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            self.authViewModel?.logout()
        }
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        // Try to extract tRPC error message
        if let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }

        return String(data: data, encoding: .utf8)
    }

    private func decodeResponse<T: Decodable>(data: Data, as type: T.Type) throws -> T {
        // First, try direct decoding
        do {
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
                print("🔍 NetworkManager: Direct decoding failed, trying tRPC format")
            #endif
        }

        // Try tRPC response format
        return try decodeTRPCResponse(data: data, as: type)
    }

    private func decodeTRPCResponse<T: Decodable>(data: Data, as type: T.Type) throws -> T {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.dataError("Invalid JSON response")
        }

        #if DEBUG
            print("🔍 NetworkManager: Response JSON structure: \(json)")
        #endif

        // Try different tRPC response formats
        if let result = json["result"] as? [String: Any],
            let resultData = result["data"] as? [String: Any],
            let jsonData = resultData["json"]
        {
            return try decodeTRPCData(jsonData, as: type)
        }

        if let result = json["result"] {
            return try decodeTRPCData(result, as: type)
        }

        // If no tRPC format found, try direct decoding again
        return try decoder.decode(type, from: data)
    }

    private func decodeTRPCData<T: Decodable>(_ data: Any, as type: T.Type) throws -> T {
        let jsonData: Data

        if data is NSNull {
            jsonData = Data()
        } else if let object = data as? [String: Any] {
            jsonData = try JSONSerialization.data(withJSONObject: object)
        } else if let array = data as? [Any] {
            jsonData = try JSONSerialization.data(withJSONObject: array)
        } else {
            // Handle primitive types
            let wrapper = ["value": data]
            jsonData = try JSONSerialization.data(withJSONObject: wrapper)
        }

        return try decoder.decode(type, from: jsonData)
    }
}
