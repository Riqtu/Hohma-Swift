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

    func request<T: Decodable>(_ endpoint: URLRequest, decoder: JSONDecoder = .init()) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endpoint)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            await MainActor.run {
                self.authViewModel?.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }
        return try decoder.decode(T.self, from: data)
    }
}
