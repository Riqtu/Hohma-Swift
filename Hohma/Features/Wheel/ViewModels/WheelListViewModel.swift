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
        guard let apiURL = apiURL else {
            self.error = "API URL не задан"
            return
        }
        
        guard let url = URL(string: "\(apiURL)/wheelList.getAll") else {
            self.error = "URL некорректный"
            return
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
        let response: WheelListResponse = try await NetworkManager.shared.request(request, decoder: decoder)
        self.wheels = response.result.data.json
        
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
}
