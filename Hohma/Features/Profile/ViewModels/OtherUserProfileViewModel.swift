//
//  OtherUserProfileViewModel.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Foundation

@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published var user: UserProfile?
    @Published var userWheels: [Wheel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userId: String
    private let profileService = ProfileService.shared

    init(userId: String) {
        self.userId = userId
    }

    func loadUserProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем профиль пользователя
            let user = try await profileService.getUserProfile(userId: userId)
            self.user = user

            // Загружаем колеса пользователя
            let wheels = try await profileService.getUserWheels(userId: userId)
            self.userWheels = wheels

        } catch {
            self.errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
