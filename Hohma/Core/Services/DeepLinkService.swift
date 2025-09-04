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
                print("🔗 DeepLinkService: ===== DEEP LINK NOTIFICATION RECEIVED =====")
                print("🔗 DeepLinkService: Received deepLinkToWheel notification")
                print("🔗 DeepLinkService: Notification userInfo: \(notification.userInfo ?? [:])")

                if let wheelId = notification.userInfo?["wheelId"] as? String {
                    print("🔗 DeepLinkService: ✅ Processing wheel ID: \(wheelId)")
                    self?.handleDeepLinkToWheel(wheelId: wheelId)
                } else {
                    print("🔗 DeepLinkService: ❌ No wheel ID found in notification")
                }
                print("🔗 DeepLinkService: ===== DEEP LINK NOTIFICATION PROCESSING COMPLETE =====")
            }
            .store(in: &cancellables)
    }

    func handleDeepLinkToWheel(wheelId: String) {
        print("🔗 DeepLinkService: ===== HANDLING DEEP LINK TO WHEEL =====")
        print("🔗 DeepLinkService: Processing deep link to wheel: \(wheelId)")

        DispatchQueue.main.async {
            self.pendingWheelId = wheelId
            self.isProcessingDeepLink = true
            print("🔗 DeepLinkService: ✅ Set pendingWheelId to: \(wheelId)")
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
