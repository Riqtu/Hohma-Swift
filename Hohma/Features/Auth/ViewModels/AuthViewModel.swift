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
        // Загружаем данные из Keychain (с автоматической миграцией из UserDefaults)
        if let savedAuthResult = KeychainService.shared.loadAuthResult() {
            self.user = savedAuthResult
            self.isAuthenticated = true
        }
    }

    private let authService = AuthService.shared

    @MainActor
    func logout() {
        AppLogger.shared.info("Logging out user", category: .auth)

        // Почистить токен, юзера, etc
        self.user = nil
        self.isAuthenticated = false
        self.errorMessage = nil

        // Очищаем сохраненные данные авторизации из Keychain
        do {
            try KeychainService.shared.deleteAuthResult()
            AppLogger.shared.info("User logged out successfully", category: .auth)
        } catch {
            AppLogger.shared.error(
                "Failed to delete authResult from Keychain", error: error, category: .auth)
        }
    }

    func handleTelegramAuth(token: String) {
        isLoading = true
        errorMessage = nil
        authService.loginWithTelegramToken(token) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.completeAuth(with: result)
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
                        self.completeAuth(with: result)
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

    func loginWithCredentials(username: String, password: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Введите логин и пароль"
            return
        }

        isLoading = true
        errorMessage = nil

        authService.loginWithCredentials(
            username: trimmedUsername,
            password: trimmedPassword
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.completeAuth(with: result)
            }
        }
    }

    func registerWithCredentials(
        username: String,
        password: String,
        email: String?,
        firstName: String?,
        lastName: String?
    ) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedUsername.count >= 3 else {
            errorMessage = "Логин должен содержать минимум 3 символа"
            return
        }

        guard trimmedPassword.count >= 8 else {
            errorMessage = "Пароль должен содержать минимум 8 символов"
            return
        }

        let sanitizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedFirstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil

        authService.registerWithCredentials(
            username: trimmedUsername,
            password: trimmedPassword,
            email: sanitizedEmail?.isEmpty == true ? nil : sanitizedEmail,
            firstName: sanitizedFirstName?.isEmpty == true ? nil : sanitizedFirstName,
            lastName: sanitizedLastName?.isEmpty == true ? nil : sanitizedLastName
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.completeAuth(with: result)
            }
        }
    }

    private func completeAuth(with result: Result<AuthResult, Error>) {
        switch result {
        case .success(let authResult):
            self.user = authResult
            self.isAuthenticated = true
        case .failure(let error):
            self.errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .auth)
        }
    }
}
