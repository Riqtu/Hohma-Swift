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

        print("🔗 AppDelegate: didFinishLaunchingWithOptions called")

        // Настраиваем push-уведомления
        setupPushNotifications()

        // Логируем launch options для отладки
        if let url = launchOptions?[.url] as? URL {
            print("🔗 AppDelegate: ===== APP LAUNCHED WITH URL =====")
            print("🔗 AppDelegate: App launched with URL: \(url)")
            // Обрабатываем URL при запуске приложения
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔗 AppDelegate: Processing launch URL after delay")
                _ = self.handleCustomURL(url: url)
            }
        } else if let userActivity = launchOptions?[.userActivityDictionary] as? [String: Any],
            let userActivityObject = userActivity["UIApplicationLaunchOptionsUserActivityKey"]
                as? NSUserActivity,
            let url = userActivityObject.webpageURL
        {
            print("🔗 AppDelegate: ===== APP LAUNCHED WITH USER ACTIVITY =====")
            print("🔗 AppDelegate: App launched with userActivity URL: \(url)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔗 AppDelegate: Processing launch userActivity URL after delay")
                _ = self.handleCustomURL(url: url)
            }
        } else {
            print("🔗 AppDelegate: App launched without URL or userActivity")
        }

        print("🔗 AppDelegate: AppDelegate setup complete")

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
        print("🔗 AppDelegate: ===== USER ACTIVITY RECEIVED =====")
        print("🔗 AppDelegate: Received userActivity: \(userActivity.activityType)")
        print(
            "🔗 AppDelegate: UserActivity URL: \(userActivity.webpageURL?.absoluteString ?? "nil")")
        print("🔗 AppDelegate: UserActivity userInfo: \(userActivity.userInfo ?? [:])")

        // Обрабатываем Universal Links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        {
            print("🔗 AppDelegate: ✅ Processing Universal Link")
            return handleUniversalLink(url: url)
        }

        // Обрабатываем custom URL schemes через userActivity
        // Это происходит когда приложение уже запущено и пользователь переходит по ссылке
        if let url = userActivity.webpageURL {
            print("🔗 AppDelegate: ✅ Processing custom URL scheme through userActivity")
            return handleCustomURL(url: url)
        }

        print("🔗 AppDelegate: ❌ Not a Universal Link or custom URL")
        print("🔗 AppDelegate: ===== USER ACTIVITY PROCESSING COMPLETE =====")
        return false
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("🔗 AppDelegate: ===== DEEP LINK RECEIVED (application:open:options) =====")
        print("🔗 AppDelegate: Received custom URL: \(url)")
        print("🔗 AppDelegate: URL scheme: \(url.scheme ?? "nil")")
        print("🔗 AppDelegate: URL host: \(url.host ?? "nil")")
        print("🔗 AppDelegate: URL path: \(url.path)")
        print("🔗 AppDelegate: URL pathComponents: \(url.pathComponents)")
        print("🔗 AppDelegate: Full URL string: \(url.absoluteString)")
        print("🔗 AppDelegate: Options: \(options)")
        print("🔗 AppDelegate: App state: \(app.applicationState.rawValue)")

        // Обрабатываем custom URL schemes
        let result = handleCustomURL(url: url)
        print("🔗 AppDelegate: handleCustomURL returned: \(result)")
        print("🔗 AppDelegate: ===== DEEP LINK PROCESSING COMPLETE =====")
        return result
    }

    private func handleUniversalLink(url: URL) -> Bool {
        print("🔗 AppDelegate: Received Universal Link: \(url)")
        print("🔗 AppDelegate: URL components: \(url.pathComponents)")

        // Парсим URL для извлечения ID колеса
        if let wheelId = extractWheelId(from: url) {
            print("🔗 AppDelegate: Extracted wheel ID: \(wheelId)")
            print("🔗 AppDelegate: Posting deepLinkToWheel notification")

            // Отправляем уведомление для навигации к колесу
            NotificationCenter.default.post(
                name: .deepLinkToWheel,
                object: nil,
                userInfo: ["wheelId": wheelId]
            )
            print("🔗 AppDelegate: Notification posted successfully")
            return true
        } else {
            print("🔗 AppDelegate: Failed to extract wheel ID from URL")
        }

        return false
    }

    private func handleCustomURL(url: URL) -> Bool {
        print("🔗 AppDelegate: ===== HANDLING CUSTOM URL =====")
        print("🔗 AppDelegate: Received Custom URL: \(url)")
        print("🔗 AppDelegate: URL scheme: \(url.scheme ?? "nil")")
        print("🔗 AppDelegate: URL host: \(url.host ?? "nil")")
        print("🔗 AppDelegate: URL path: \(url.path)")

        // Обрабатываем custom URL schemes для riqtu.Hohma:// и hohma://
        if url.scheme == "riqtu.Hohma" || url.scheme == "hohma" {
            print("🔗 AppDelegate: ✅ URL scheme matches expected schemes")

            // Парсим URL для извлечения ID колеса
            if let wheelId = extractWheelId(from: url) {
                print("🔗 AppDelegate: ✅ Extracted wheel ID from custom URL: \(wheelId)")

                // Отправляем уведомление для навигации к колесу
                print("🔗 AppDelegate: 📤 Posting deepLinkToWheel notification...")
                NotificationCenter.default.post(
                    name: .deepLinkToWheel,
                    object: nil,
                    userInfo: ["wheelId": wheelId]
                )
                print("🔗 AppDelegate: ✅ Custom URL notification posted successfully")
                return true
            } else {
                print("🔗 AppDelegate: ❌ Failed to extract wheel ID from custom URL")
            }
        }
        // Дополнительная проверка для Universal Links с доменом hohma.su
        else if url.scheme == "https" && url.host == "hohma.su" {
            print("🔗 AppDelegate: ✅ Processing Universal Link with hohma.su domain")
            return handleUniversalLink(url: url)
        } else {
            print(
                "🔗 AppDelegate: ❌ URL scheme '\(url.scheme ?? "nil")' does not match expected schemes (riqtu.Hohma, hohma, or https)"
            )
        }

        print("🔗 AppDelegate: ===== CUSTOM URL HANDLING COMPLETE =====")
        return false
    }

    private func extractWheelId(from url: URL) -> String? {
        print("🔗 AppDelegate: Extracting wheel ID from URL: \(url)")
        print("🔗 AppDelegate: URL scheme: \(url.scheme ?? "nil")")
        print("🔗 AppDelegate: URL host: \(url.host ?? "nil")")
        print("🔗 AppDelegate: URL path: \(url.path)")
        print("🔗 AppDelegate: URL pathComponents: \(url.pathComponents)")

        let pathComponents = url.pathComponents
        print("🔗 AppDelegate: Path components: \(pathComponents)")

        // Для custom URL scheme: riqtu.Hohma://fortune-wheel/{wheelId}
        // host = "fortune-wheel", path = "/{wheelId}"
        if let host = url.host, host == "fortune-wheel" && pathComponents.count >= 2 {
            let wheelId = pathComponents[1]  // pathComponents[0] = "/", pathComponents[1] = wheelId
            print("🔗 AppDelegate: Extracted wheel ID from custom scheme: \(wheelId)")
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
                print("🔗 AppDelegate: Extracted wheel ID from path with fortune-wheel: \(wheelId)")
                return wheelId
            }

            // Если нет "fortune-wheel", но есть ID в path (например, riqtu.Hohma:///{wheelId})
            if pathComponents.count == 2 && pathComponents[0] == "/" {
                let wheelId = pathComponents[1]
                print("🔗 AppDelegate: Extracted wheel ID from simple path: \(wheelId)")
                return wheelId
            }
        }

        // Для Universal Links: https://hohma.su/fortune-wheel/{wheelId}
        // Ищем индекс "fortune-wheel" в пути
        if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
            fortuneWheelIndex + 1 < pathComponents.count
        {
            let wheelId = pathComponents[fortuneWheelIndex + 1]
            print("🔗 AppDelegate: Extracted wheel ID from universal link: \(wheelId)")
            return wheelId
        }

        print("🔗 AppDelegate: Failed to extract wheel ID")
        return nil
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
        print("❌ AppDelegate: Failed to register for remote notifications: \(error)")
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
        print("📱 AppDelegate: Received remote notification: \(userInfo)")

        // Создаем локальное уведомление для отображения
        if let aps = userInfo["aps"] as? [String: Any],
            let alert = aps["alert"] as? [String: Any],
            let title = alert["title"] as? String,
            let body = alert["body"] as? String
        {

            let type =
                PushNotificationType(rawValue: userInfo["type"] as? String ?? "general") ?? .general

            // Показываем локальное уведомление
            PushNotificationService.shared.scheduleLocalNotification(
                type: type,
                title: title,
                body: body,
                userInfo: [:]
            )
        }
    }
}
