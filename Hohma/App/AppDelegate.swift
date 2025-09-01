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

        // Настраиваем push-уведомления
        setupPushNotifications()

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
        // Обрабатываем Universal Links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        {
            return handleUniversalLink(url: url)
        }
        return false
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Обрабатываем custom URL schemes
        return handleCustomURL(url: url)
    }

    private func handleUniversalLink(url: URL) -> Bool {
        print("🔗 AppDelegate: Received Universal Link: \(url)")

        // Парсим URL для извлечения ID колеса
        if let wheelId = extractWheelId(from: url) {
            // Отправляем уведомление для навигации к колесу
            NotificationCenter.default.post(
                name: .deepLinkToWheel,
                object: nil,
                userInfo: ["wheelId": wheelId]
            )
            return true
        }

        return false
    }

    private func handleCustomURL(url: URL) -> Bool {
        print("🔗 AppDelegate: Received Custom URL: \(url)")

        // Обрабатываем custom URL schemes если понадобится в будущем
        return false
    }

    private func extractWheelId(from url: URL) -> String? {
        // Парсим URL вида: https://hohma.su/fortune-wheel/{wheelId}
        let pathComponents = url.pathComponents

        // Ищем индекс "fortune-wheel" в пути
        if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
            fortuneWheelIndex + 1 < pathComponents.count
        {
            let wheelId = pathComponents[fortuneWheelIndex + 1]
            print("🔗 AppDelegate: Extracted wheel ID: \(wheelId)")
            return wheelId
        }

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
