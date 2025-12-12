//
//  DeepLinkService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Foundation

class DeepLinkService: ObservableObject {
    static let shared = DeepLinkService()

    @Published var pendingWheelId: String?
    @Published var isProcessingDeepLink = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotificationHandling()
    }

    private func setupNotificationHandling() {
        // Слушаем уведомления о deep links
        NotificationCenter.default.publisher(for: .deepLinkToWheel)
            .sink { [weak self] notification in
                AppLogger.shared.debug("===== DEEP LINK NOTIFICATION RECEIVED =====", category: .general)
                AppLogger.shared.debug("Received deepLinkToWheel notification", category: .general)
                AppLogger.shared.debug("Notification userInfo: \(notification.userInfo ?? [:])", category: .general)

                if let wheelId = notification.userInfo?["wheelId"] as? String {
                    AppLogger.shared.debug("Processing wheel ID: \(wheelId)", category: .general)
                    self?.handleDeepLinkToWheel(wheelId: wheelId)
                } else {
                    AppLogger.shared.warning("No wheel ID found in notification", category: .general)
                }
                AppLogger.shared.debug("===== DEEP LINK NOTIFICATION PROCESSING COMPLETE =====", category: .general)
            }
            .store(in: &cancellables)
    }

    func handleDeepLinkToWheel(wheelId: String) {
        AppLogger.shared.debug("===== HANDLING DEEP LINK TO WHEEL =====", category: .general)
        AppLogger.shared.debug("Processing deep link to wheel: \(wheelId)", category: .general)

        DispatchQueue.main.async {
            self.pendingWheelId = wheelId
            self.isProcessingDeepLink = true
            AppLogger.shared.debug("Set pendingWheelId to: \(wheelId)", category: .general)
            print("🔗 DeepLinkService: ✅ Set isProcessingDeepLink to: true")

            // Отправляем уведомление для навигации к конкретному колесу
            print("🔗 DeepLinkService: 📤 Posting navigationRequested notification...")
            let userInfo = [
                "destination": "wheel",
                "wheelId": wheelId,
                "force": true,
            ]
            print("🔗 DeepLinkService: UserInfo: \(userInfo)")

            NotificationCenter.default.post(
                name: .navigationRequested,
                object: nil,
                userInfo: userInfo
            )
            print("🔗 DeepLinkService: ✅ Navigation notification posted successfully")
            print("🔗 DeepLinkService: ===== DEEP LINK TO WHEEL HANDLING COMPLETE =====")
        }
    }

    func clearPendingDeepLink() {
        pendingWheelId = nil
        isProcessingDeepLink = false
    }

    func getPendingWheelId() -> String? {
        let wheelId = pendingWheelId
        clearPendingDeepLink()
        return wheelId
    }
}
