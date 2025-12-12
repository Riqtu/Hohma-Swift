import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var isUpdating = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Форма редактирования
    @Published var username: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var avatarUrl: String = ""

    private let profileService = ProfileService.shared
    private let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        loadProfile()
    }

    func loadProfile() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let profile = try await profileService.getProfile()
                self.user = profile

                // Заполняем форму текущими данными
                self.username = profile.username ?? ""
                self.firstName = profile.firstName ?? ""
                self.lastName = profile.lastName ?? ""
                self.avatarUrl = profile.avatarUrl?.absoluteString ?? ""

            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func updateProfile() {
        guard let user = user else { return }

        Task {
            isUpdating = true
            errorMessage = nil
            successMessage = nil

            do {
                let updateRequest = ProfileUpdateRequest(
                    id: user.id,
                    data: ProfileUpdateData(
                        username: username.isEmpty ? nil : username,
                        firstName: firstName.isEmpty ? nil : firstName,
                        lastName: lastName.isEmpty ? nil : lastName,
                        avatarUrl: avatarUrl.isEmpty ? nil : avatarUrl
                    )
                )

                let updatedUser = try await profileService.updateProfile(updateRequest)
                self.user = updatedUser
                successMessage = "Профиль успешно обновлен"

                // Обновляем данные в Keychain
                if var authResult = KeychainService.shared.loadAuthResult() {
                    authResult.user = updatedUser
                    do {
                        try KeychainService.shared.saveAuthResult(authResult)
                    } catch {
                        #if DEBUG
                            print(
                                "⚠️ ProfileViewModel: Failed to update authResult in Keychain: \(error)"
                            )
                        #endif
                    }
                }

            } catch {
                errorMessage = error.localizedDescription
            }

            isUpdating = false
        }
    }

    func logout() {
        authViewModel.logout()
    }

    func deleteAccount() {
        Task {
            isDeleting = true
            errorMessage = nil

            do {
                try await profileService.deleteAccount()
                // После успешного удаления аккаунта выполняем выход
                authViewModel.logout()
            } catch {
                errorMessage = error.localizedDescription
            }

            isDeleting = false
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
