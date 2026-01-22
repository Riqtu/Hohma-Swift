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
            AppLogger.shared.debug("Set isProcessingDeepLink to: true", category: .general)

            // Отправляем уведомление для навигации к конкретному колесу
            AppLogger.shared.debug("Posting navigationRequested notification...", category: .general)
            let userInfo = [
                "destination": "wheel",
                "wheelId": wheelId,
                "force": true,
            ]
            AppLogger.shared.debug("UserInfo: \(userInfo)", category: .general)

            NotificationCenter.default.post(
                name: .navigationRequested,
                object: nil,
                userInfo: userInfo
            )
            AppLogger.shared.debug("Navigation notification posted successfully", category: .general)
            AppLogger.shared.debug("DEEP LINK TO WHEEL HANDLING COMPLETE", category: .general)
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
    
    // MARK: - URL Parsing
    
    /// Унифицированный метод для извлечения wheelId из URL
    /// Используется в RootView и AppDelegate для обработки deep links
    static func extractWheelId(from url: URL) -> String? {
        AppLogger.shared.debug("Extracting wheel ID from URL: \(url)", category: .general)
        AppLogger.shared.debug("URL scheme: \(url.scheme ?? "nil")", category: .general)
        AppLogger.shared.debug("URL host: \(url.host ?? "nil")", category: .general)
        AppLogger.shared.debug("URL path: \(url.path)", category: .general)
        AppLogger.shared.debug("URL pathComponents: \(url.pathComponents)", category: .general)

        let pathComponents = url.pathComponents
        AppLogger.shared.debug("Path components: \(pathComponents)", category: .general)

        // Для custom URL scheme: riqtu.Hohma://fortune-wheel/{wheelId}
        // host = "fortune-wheel", path = "/{wheelId}"
        if let host = url.host, host == "fortune-wheel" && pathComponents.count >= 2 {
            let wheelId = pathComponents[1]  // pathComponents[0] = "/", pathComponents[1] = wheelId
            AppLogger.shared.debug("Extracted wheel ID from custom scheme: \(wheelId)", category: .general)
            return wheelId
        }

        // Дополнительная проверка для случая, когда wheelId находится в path без host
        // Например: riqtu.Hohma:///fortune-wheel/{wheelId} или riqtu.Hohma:///{wheelId}
        if pathComponents.count >= 2 {
            // Проверяем, есть ли "fortune-wheel" в path
            if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
                fortuneWheelIndex + 1 < pathComponents.count
            {
                let wheelId = pathComponents[fortuneWheelIndex + 1]
                AppLogger.shared.debug("Extracted wheel ID from path with fortune-wheel: \(wheelId)", category: .general)
                return wheelId
            }

            // Если нет "fortune-wheel", но есть ID в path (например, riqtu.Hohma:///{wheelId})
            if pathComponents.count == 2 && pathComponents[0] == "/" {
                let wheelId = pathComponents[1]
                AppLogger.shared.debug("Extracted wheel ID from simple path: \(wheelId)", category: .general)
                return wheelId
            }
        }

        // Для Universal Links: https://hohma.su/fortune-wheel/{wheelId}
        // Ищем индекс "fortune-wheel" в пути
        if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
            fortuneWheelIndex + 1 < pathComponents.count
        {
            let wheelId = pathComponents[fortuneWheelIndex + 1]
            AppLogger.shared.debug("Extracted wheel ID from universal link: \(wheelId)", category: .general)
            return wheelId
        }

        AppLogger.shared.debug("Failed to extract wheel ID", category: .general)
        return nil
    }
}
