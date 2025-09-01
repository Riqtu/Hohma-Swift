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
                if let wheelId = notification.userInfo?["wheelId"] as? String {
                    self?.handleDeepLinkToWheel(wheelId: wheelId)
                }
            }
            .store(in: &cancellables)
    }

    func handleDeepLinkToWheel(wheelId: String) {
        print("🔗 DeepLinkService: Processing deep link to wheel: \(wheelId)")

        DispatchQueue.main.async {
            self.pendingWheelId = wheelId
            self.isProcessingDeepLink = true

            // Отправляем уведомление для навигации к списку колес
            NotificationCenter.default.post(
                name: .navigationRequested,
                object: nil,
                userInfo: [
                    "destination": "wheelList",
                    "force": true,
                ]
            )
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
