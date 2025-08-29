//
//  NetworkManager+Extensions.swift
//  Hohma
//
//  Created by Artem Vydro on 07.08.2025.
//

import Foundation

// MARK: - NetworkManager Extensions
extension NetworkManager {

    // MARK: - Retry Logic
    func requestWithRetry<T: Decodable>(
        _ endpoint: URLRequest,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await request(endpoint)
            } catch {
                lastError = error

                // Don't retry on authentication errors
                if error is AppError {
                    throw error
                }

                // Don't retry on the last attempt
                if attempt == maxRetries {
                    break
                }

                #if DEBUG
                    print(
                        "🔄 NetworkManager: Retry attempt \(attempt)/\(maxRetries) after error: \(error)"
                    )
                #endif

                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }

        throw lastError ?? AppError.networkError("Request failed after \(maxRetries) attempts")
    }

    // MARK: - Request Builders
    func createRequest(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Hohma-iOS/1.0", forHTTPHeaderField: "User-Agent")

        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    // MARK: - Convenience Methods
    func get<T: Decodable>(_ url: URL, headers: [String: String] = [:]) async throws -> T {
        let urlRequest = createRequest(url: url, method: .GET, headers: headers)
        return try await NetworkManager.shared.request(urlRequest)
    }

    func post<T: Decodable, U: Encodable>(
        _ url: URL,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let urlRequest = createRequest(url: url, method: .POST, headers: headers, body: bodyData)
        return try await NetworkManager.shared.request(urlRequest)
    }

    func put<T: Decodable, U: Encodable>(
        _ url: URL,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let urlRequest = createRequest(url: url, method: .PUT, headers: headers, body: bodyData)
        return try await NetworkManager.shared.request(urlRequest)
    }

    func delete<T: Decodable>(_ url: URL, headers: [String: String] = [:]) async throws -> T {
        let urlRequest = createRequest(url: url, method: .DELETE, headers: headers)
        return try await NetworkManager.shared.request(urlRequest)
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Request Configuration
struct NetworkRequestConfig {
    let timeout: TimeInterval
    let retryCount: Int
    let retryDelay: TimeInterval
    let cachePolicy: URLRequest.CachePolicy

    static let `default` = NetworkRequestConfig(
        timeout: 30.0,
        retryCount: 3,
        retryDelay: 1.0,
        cachePolicy: .useProtocolCachePolicy
    )

    static let aggressive = NetworkRequestConfig(
        timeout: 10.0,
        retryCount: 5,
        retryDelay: 0.5,
        cachePolicy: .reloadIgnoringLocalCacheData
    )

    static let conservative = NetworkRequestConfig(
        timeout: 60.0,
        retryCount: 1,
        retryDelay: 2.0,
        cachePolicy: .returnCacheDataElseLoad
    )
}
