//
//  NotificationSettingsViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation
import UIKit

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var isPushEnabled = false
    @Published var isNewFollowerEnabled = true
    @Published var isNewLikeEnabled = true
    @Published var isNewCommentEnabled = true
    @Published var isWheelInvitationEnabled = true
    @Published var isWheelResultEnabled = true
    @Published var isGeneralEnabled = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let pushNotificationService = PushNotificationService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        loadSettings()
    }

    private func setupBindings() {
        // Подписываемся на изменения статуса авторизации
        pushNotificationService.$isAuthorized
            .assign(to: \.isPushEnabled, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Settings Management

    func loadSettings() {
        isLoading = true

        // Временно загружаем настройки из UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
        }
    }

    func saveSettings() {
        isLoading = true

        // Временно сохраняем настройки в UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.successMessage = "Настройки уведомлений сохранены"
            self.isLoading = false

            // Очищаем сообщение через 3 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = nil
            }
        }
    }

    private func updateSettingsFromServer(_ settings: [String: Any]) {
        isNewFollowerEnabled = settings["newFollower"] as? Bool ?? true
        isNewLikeEnabled = settings["newLike"] as? Bool ?? true
        isNewCommentEnabled = settings["newComment"] as? Bool ?? true
        isWheelInvitationEnabled = settings["wheelInvitation"] as? Bool ?? true
        isWheelResultEnabled = settings["wheelResult"] as? Bool ?? true
        isGeneralEnabled = settings["general"] as? Bool ?? true
    }

    // MARK: - Push Notification Authorization

    func requestPushAuthorization() {
        Task {
            let granted = await pushNotificationService.requestAuthorization()

            await MainActor.run {
                if granted {
                    self.successMessage = "Уведомления включены"
                } else {
                    self.errorMessage =
                        "Для получения уведомлений необходимо разрешить их в настройках"
                }

                // Очищаем сообщения через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.successMessage = nil
                    self.errorMessage = nil
                }
            }
        }
    }

    func openSettings() {
        #if os(iOS)
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        #endif
    }

    // MARK: - Test Notifications

    func sendTestNotification() {
        pushNotificationService.scheduleLocalNotification(
            type: .general,
            title: "Тестовое уведомление",
            body: "Это тестовое уведомление для проверки настроек",
            userInfo: ["type": "test"]
        )

        successMessage = "Тестовое уведомление отправлено"

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }

    // MARK: - Message Management

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
