//
//  AuthViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: AuthResult?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init() {
        if let authResultData = UserDefaults.standard.data(forKey: "authResult"),
           let savedAuthResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData) {
            self.user = savedAuthResult
            self.isAuthenticated = true
        }
    }
    
    private let authService = AuthService.shared
    
    @MainActor
    func logout() {
        // Почистить токен, юзера, etc
        self.user = nil
        self.isAuthenticated = false
    }
    
    func handleTelegramAuth(token: String) {
        isLoading = true
        errorMessage = nil
        authService.loginWithTelegramToken(token) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let user):
                    self?.user = user
                    self?.isAuthenticated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
