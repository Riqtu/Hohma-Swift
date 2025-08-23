//
//  AuthViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import Combine
import Foundation

final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: AuthResult?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {
        if let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let savedAuthResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        {
            self.user = savedAuthResult
            self.isAuthenticated = true
        }
    }

    private let authService = AuthService.shared

    @MainActor
    func logout() {
        #if DEBUG
            print("🔐 AuthViewModel: Logging out user")
        #endif

        // Почистить токен, юзера, etc
        self.user = nil
        self.isAuthenticated = false
        self.errorMessage = nil

        // Очищаем сохраненные данные авторизации
        UserDefaults.standard.removeObject(forKey: "authResult")

        #if DEBUG
            print("🔐 AuthViewModel: User logged out successfully")
        #endif
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

    func handleAppleAuth() {
        isLoading = true
        errorMessage = nil

        Task {
            if let appleRequest = await AppleAuthService.shared.signInWithApple() {
                authService.loginWithApple(appleRequest) { result in
                    Task { @MainActor in
                        self.isLoading = false
                        switch result {
                        case .success(let user):
                            self.user = user
                            self.isAuthenticated = true
                        case .failure(let error):
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Apple авторизация не удалась"
                }
            }
        }
    }
}
