//
//  WheelListViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

@MainActor
class WheelListViewModel: ObservableObject {
    @Published var wheels: [WheelWithRelations] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String?
    let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String

    let user: AuthResult?

    init(user: AuthResult?) {
        self.user = user
    }

    func loadWheels() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newWheels = try await fetchWheels()
            self.wheels = newWheels

        } catch is CancellationError {
            #if DEBUG
                print("Загрузка отменена")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
                print(error)
            #endif
        }
    }

    func refreshWheels() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newWheels = try await fetchWheels()
            self.wheels = newWheels

        } catch is CancellationError {
            #if DEBUG
                print("Обновление отменено")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
                print(error)
            #endif
        }
    }

    private func fetchWheels() async throws -> [WheelWithRelations] {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.getAll") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Передаём токен
        if let user = user {
            request.setValue("Bearer \(user.token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
            let (data, _) = try await URLSession.shared.data(for: request)
            if let rawString = String(data: data, encoding: .utf8) {
                print("Raw server response:", rawString)
            }
        #else
            let (data, _) = try await URLSession.shared.data(for: request)
        #endif

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withMilliseconds
        let response: WheelListResponse = try await NetworkManager.shared.request(
            request, decoder: decoder)

        return response.result.data.json
    }
}
