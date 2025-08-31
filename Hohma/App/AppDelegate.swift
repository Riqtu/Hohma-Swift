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
