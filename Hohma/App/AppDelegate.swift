//
//  AppDelegate.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        AppLogger.shared.debug("didFinishLaunchingWithOptions called", category: .general)

        // Настраиваем push-уведомления
        setupPushNotifications()

        // Логируем launch options для отладки
        if let url = launchOptions?[.url] as? URL {
            AppLogger.shared.debug("===== APP LAUNCHED WITH URL =====", category: .general)
            AppLogger.shared.debug("App launched with URL: \(url)", category: .general)
            // Обрабатываем URL при запуске приложения
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AppLogger.shared.debug("Processing launch URL after delay", category: .general)
                _ = self.handleCustomURL(url: url)
            }
        } else if let userActivity = launchOptions?[.userActivityDictionary] as? [String: Any],
            let userActivityObject = userActivity["UIApplicationLaunchOptionsUserActivityKey"]
                as? NSUserActivity,
            let url = userActivityObject.webpageURL
        {
            AppLogger.shared.debug("===== APP LAUNCHED WITH USER ACTIVITY =====", category: .general)
            AppLogger.shared.debug("App launched with userActivity URL: \(url)", category: .general)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AppLogger.shared.debug("Processing launch userActivity URL after delay", category: .general)
                _ = self.handleCustomURL(url: url)
            }
        } else {
            AppLogger.shared.debug("App launched without URL or userActivity", category: .general)
        }

        AppLogger.shared.debug("AppDelegate setup complete", category: .general)

        return true
    }

    private func setupPushNotifications() {
        // Регистрируемся для push-уведомлений
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Universal Links & Deep Linking

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppLogger.shared.debug("===== USER ACTIVITY RECEIVED =====", category: .general)
        AppLogger.shared.debug("Received userActivity: \(userActivity.activityType)", category: .general)
        AppLogger.shared.debug(
            "AppDelegate: UserActivity URL: \(userActivity.webpageURL?.absoluteString ?? "nil")", category: .general)
        AppLogger.shared.debug("UserActivity userInfo: \(userActivity.userInfo ?? [:])", category: .general)

        // Обрабатываем Universal Links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        {
            AppLogger.shared.info("Processing Universal Link", category: .general)
            return handleUniversalLink(url: url)
        }

        // Обрабатываем custom URL schemes через userActivity
        // Это происходит когда приложение уже запущено и пользователь переходит по ссылке
        if let url = userActivity.webpageURL {
            AppLogger.shared.info("Processing custom URL scheme through userActivity", category: .general)
            return handleCustomURL(url: url)
        }

        AppLogger.shared.error("Not a Universal Link or custom URL", category: .general)
        AppLogger.shared.debug("===== USER ACTIVITY PROCESSING COMPLETE =====", category: .general)
        return false
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppLogger.shared.debug("===== DEEP LINK RECEIVED (application:open:options) =====", category: .general)
        AppLogger.shared.debug("Received custom URL: \(url)", category: .general)
        AppLogger.shared.debug("URL scheme: \(url.scheme ?? "nil")", category: .general)
        AppLogger.shared.debug("URL host: \(url.host ?? "nil")", category: .general)
        AppLogger.shared.debug("URL path: \(url.path)", category: .general)
        AppLogger.shared.debug("URL pathComponents: \(url.pathComponents)", category: .general)
        AppLogger.shared.debug("Full URL string: \(url.absoluteString)", category: .general)
        AppLogger.shared.debug("Options: \(options)", category: .general)
        AppLogger.shared.debug("App state: \(app.applicationState.rawValue)", category: .general)

        // Обрабатываем custom URL schemes
        let result = handleCustomURL(url: url)
        AppLogger.shared.debug("handleCustomURL returned: \(result)", category: .general)
        AppLogger.shared.debug("===== DEEP LINK PROCESSING COMPLETE =====", category: .general)
        return result
    }

    private func handleUniversalLink(url: URL) -> Bool {
        AppLogger.shared.debug("Received Universal Link: \(url)", category: .general)
        AppLogger.shared.debug("URL components: \(url.pathComponents)", category: .general)

        // Парсим URL для извлечения ID колеса
        if let wheelId = DeepLinkService.extractWheelId(from: url) {
            AppLogger.shared.debug("Extracted wheel ID: \(wheelId)", category: .general)
            AppLogger.shared.debug("Posting deepLinkToWheel notification", category: .general)

            // Отправляем уведомление для навигации к колесу
            NotificationCenter.default.post(
                name: .deepLinkToWheel,
                object: nil,
                userInfo: ["wheelId": wheelId]
            )
            AppLogger.shared.debug("Notification posted successfully", category: .general)
            return true
        } else {
            AppLogger.shared.debug("Failed to extract wheel ID from URL", category: .general)
        }

        return false
    }

    private func handleCustomURL(url: URL) -> Bool {
        AppLogger.shared.debug("===== HANDLING CUSTOM URL =====", category: .general)
        AppLogger.shared.debug("Received Custom URL: \(url)", category: .general)
        AppLogger.shared.debug("URL scheme: \(url.scheme ?? "nil")", category: .general)
        AppLogger.shared.debug("URL host: \(url.host ?? "nil")", category: .general)
        AppLogger.shared.debug("URL path: \(url.path)", category: .general)

        // Обрабатываем custom URL schemes для riqtu.Hohma:// и hohma://
        if url.scheme == "riqtu.Hohma" || url.scheme == "hohma" {
            AppLogger.shared.info("URL scheme matches expected schemes", category: .general)

            // Парсим URL для извлечения ID колеса
            if let wheelId = DeepLinkService.extractWheelId(from: url) {
                AppLogger.shared.info("Extracted wheel ID from custom URL: \(wheelId)", category: .general)

                // Отправляем уведомление для навигации к колесу
                AppLogger.shared.debug("Posting deepLinkToWheel notification...", category: .general)
                NotificationCenter.default.post(
                    name: .deepLinkToWheel,
                    object: nil,
                    userInfo: ["wheelId": wheelId]
                )
                AppLogger.shared.info("Custom URL notification posted successfully", category: .general)
                return true
            } else {
                AppLogger.shared.error("Failed to extract wheel ID from custom URL", category: .general)
            }
        }
        // Дополнительная проверка для Universal Links с доменом hohma.su
        else if url.scheme == "https" && url.host == "hohma.su" {
            AppLogger.shared.info("Processing Universal Link with hohma.su domain", category: .general)
            return handleUniversalLink(url: url)
        } else {
            AppLogger.shared.warning(
                "AppDelegate: URL scheme '\(url.scheme ?? "nil")' does not match expected schemes (riqtu.Hohma, hohma, or https)", category: .general)
        }

        AppLogger.shared.debug("===== CUSTOM URL HANDLING COMPLETE =====", category: .general)
        return false
    }


    // MARK: - Push Notification Methods

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Получаем device token и передаем его в сервис
        PushNotificationService.shared.setDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.shared.error("Failed to register for remote notifications: \(error)", category: .general)
    }

    func application(
        _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {

        // Обрабатываем push-уведомление
        handleRemoteNotification(userInfo)

        // Вызываем completion handler
        completionHandler(.newData)
    }

    private func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        AppLogger.shared.debug("Received remote notification: \(userInfo)", category: .general)

        // Обновляем последнее уведомление в сервисе для внутреннего использования
        // НЕ создаем локальное уведомление - система iOS сама покажет remote push
        if let pushNotification = PushNotification(from: userInfo) {
            DispatchQueue.main.async {
                PushNotificationService.shared.lastNotification = pushNotification
            }
        }
        
        // Обрабатываем данные уведомления (например, обновляем badge, синхронизируем данные и т.д.)
        // Но НЕ создаем новое локальное уведомление - система уже покажет push
    }
}
