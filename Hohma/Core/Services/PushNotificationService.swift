//
//  PushNotificationService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import UIKit
import UserNotifications

// MARK: - Notification Types
enum PushNotificationType: String, CaseIterable {
    case newFollower = "new_follower"
    case newLike = "new_like"
    case newComment = "new_comment"
    case wheelInvitation = "wheel_invitation"
    case wheelResult = "wheel_result"
    case chatMessage = "chat_message"
    case general = "general"

    var title: String {
        switch self {
        case .newFollower:
            return "Новый подписчик"
        case .newLike:
            return "Новый лайк"
        case .newComment:
            return "Новый комментарий"
        case .wheelInvitation:
            return "Приглашение в колесо"
        case .wheelResult:
            return "Результат колеса"
        case .chatMessage:
            return "Новое сообщение"
        case .general:
            return "Уведомление"
        }
    }

    var sound: UNNotificationSound {
        switch self {
        case .newFollower:
            return UNNotificationSound.default
        case .newLike, .newComment:
            return UNNotificationSound.default
        case .wheelInvitation, .wheelResult:
            return UNNotificationSound.default
        case .chatMessage:
            return UNNotificationSound.default
        case .general:
            return UNNotificationSound.default
        }
    }
}

// MARK: - Push Notification Service
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var isAuthorized = false
    @Published var deviceToken: String?
    @Published var lastNotification: PushNotification?

    private override init() {
        super.init()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("❌ PushNotificationService: Authorization error: \(error)")
            return false
        }
    }

    // MARK: - Notification Settings
    func configureNotificationSettings() {
        // Настраиваем типы уведомлений
        let notificationCenter = UNUserNotificationCenter.current()

        // Получаем текущие настройки
        notificationCenter.getNotificationSettings { settings in
            print("📱 PushNotificationService: Current notification settings:")
            print("   - Authorization status: \(settings.authorizationStatus.rawValue)")
            print("   - Alert setting: \(settings.alertSetting.rawValue)")
            print("   - Badge setting: \(settings.badgeSetting.rawValue)")
            print("   - Sound setting: \(settings.soundSetting.rawValue)")
            print(
                "   - Notification center setting: \(settings.notificationCenterSetting.rawValue)")
            print("   - Lock screen setting: \(settings.lockScreenSetting.rawValue)")
        }
    }

    func openNotificationSettings() {
        // Открываем настройки уведомлений приложения
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Device Token
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func setDeviceToken(_ deviceToken: Data) {
        // Конвертируем Data в hex строку для APNs
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("📱 PushNotificationService: Raw device token length: \(deviceToken.count)")
        print("📱 PushNotificationService: Hex device token length: \(tokenString.count)")
        print("📱 PushNotificationService: Device token: \(tokenString)")

        // Отправляем токен на сервер
        sendDeviceTokenToServer(tokenString)
    }

    private func sendDeviceTokenToServer(_ token: String) {
        // Сохраняем локально
        UserDefaults.standard.set(token, forKey: "deviceToken")
        print("✅ PushNotificationService: Device token saved locally")

        // Отправляем на сервер через TRPC
        Task {
            await sendTokenToServer(token)
        }
    }

    private func sendTokenToServer(_ token: String) async {
        do {
            print(
                "📱 PushNotificationService: Sending token to server: \(String(token.prefix(10)))..."
            )

            // Получаем ID пользователя из TRPC сервиса
            let userId = try TRPCService.shared.getCurrentUserId()
            print("📱 PushNotificationService: User ID: \(userId)")

            // Отправляем device token через TRPC
            let response = try await saveDeviceToken(userId: userId, deviceToken: token)

            if response.success {
                print("✅ PushNotificationService: Device token sent to server successfully")
            } else {
                print("❌ PushNotificationService: Failed to save device token on server")
            }
        } catch {
            print("❌ PushNotificationService: Error sending device token: \(error)")
        }
    }

    // MARK: - Server Communication
    @MainActor
    func saveDeviceToken(userId: String, deviceToken: String) async throws
        -> SaveDeviceTokenResponse
    {
        return try await TRPCService.shared.executePOST(
            endpoint: "pushNotifications.saveDeviceToken",
            body: [
                "userId": userId,
                "deviceToken": deviceToken,
            ]
        )
    }

    @MainActor
    func getDeviceToken(userId: String) async throws -> GetDeviceTokenResponse {
        return try await TRPCService.shared.executeGET(
            endpoint: "pushNotifications.getDeviceToken",
            input: [
                "userId": userId
            ]
        )
    }

    @MainActor
    func removeDeviceToken(userId: String) async throws -> RemoveDeviceTokenResponse {
        return try await TRPCService.shared.executePOST(
            endpoint: "pushNotifications.removeDeviceToken",
            body: [
                "userId": userId
            ]
        )
    }

    // MARK: - Local Notifications
    func scheduleLocalNotification(
        type: PushNotificationType,
        title: String,
        body: String,
        userInfo: [String: Any] = [:],
        timeInterval: TimeInterval = 1.0
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = type.sound
        content.userInfo = userInfo
        content.categoryIdentifier = type.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ PushNotificationService: Failed to schedule notification: \(error)")
            } else {
                print("✅ PushNotificationService: Local notification scheduled")
            }
        }
    }

    // MARK: - Application Icon Badge
    /// Обновляет badge на иконке приложения
    func updateApplicationIconBadge(_ count: Int) {
        #if os(iOS)
            DispatchQueue.main.async {
                if #available(iOS 17.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(count) { error in
                        if let error = error {
                            print("❌ PushNotificationService: Failed to set badge count: \(error)")
                        } else {
                            print(
                                "📱 PushNotificationService: Updated application icon badge to \(count)"
                            )
                        }
                    }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = count
                    print("📱 PushNotificationService: Updated application icon badge to \(count)")
                }
            }
        #endif
    }

    /// Очищает badge на иконке приложения
    func clearApplicationIconBadge() {
        updateApplicationIconBadge(0)
    }

    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let categories: Set<UNNotificationCategory> = [
            createFollowerCategory(),
            createWheelCategory(),
            createChatCategory(),
            createGeneralCategory(),
        ]

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    private func createFollowerCategory() -> UNNotificationCategory {
        let followAction = UNNotificationAction(
            identifier: "FOLLOW_ACTION",
            title: "Подписаться",
            options: [.foreground]
        )

        let viewProfileAction = UNNotificationAction(
            identifier: "VIEW_PROFILE_ACTION",
            title: "Посмотреть профиль",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: PushNotificationType.newFollower.rawValue,
            actions: [followAction, viewProfileAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createWheelCategory() -> UNNotificationCategory {
        let joinAction = UNNotificationAction(
            identifier: "JOIN_WHEEL_ACTION",
            title: "Присоединиться",
            options: [.foreground]
        )

        let viewResultAction = UNNotificationAction(
            identifier: "VIEW_RESULT_ACTION",
            title: "Посмотреть результат",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: PushNotificationType.wheelInvitation.rawValue,
            actions: [joinAction, viewResultAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createChatCategory() -> UNNotificationCategory {
        let openChatAction = UNNotificationAction(
            identifier: "OPEN_CHAT_ACTION",
            title: "Открыть чат",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: PushNotificationType.chatMessage.rawValue,
            actions: [openChatAction],
            intentIdentifiers: [],
            options: []
        )
    }

    private func createGeneralCategory() -> UNNotificationCategory {
        let openAction = UNNotificationAction(
            identifier: "OPEN_ACTION",
            title: "Открыть",
            options: [.foreground]
        )

        return UNNotificationCategory(
            identifier: PushNotificationType.general.rawValue,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(count) { error in
                    if let error = error {
                        print("❌ PushNotificationService: Failed to set badge count: \(error)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - Push Notification Response Models
struct SaveDeviceTokenResponse: Codable {
    let success: Bool
}

struct GetDeviceTokenResponse: Codable {
    let deviceToken: String?
}

struct RemoveDeviceTokenResponse: Codable {
    let success: Bool
}

// MARK: - Push Notification Model
struct PushNotification {
    let id: String
    let type: PushNotificationType
    let title: String
    let body: String
    let userInfo: [String: String]
    let timestamp: Date

    init?(from userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
            let alert = aps["alert"] as? [String: Any],
            let title = alert["title"] as? String,
            let body = alert["body"] as? String
        else {
            return nil
        }

        self.id = UUID().uuidString
        self.type =
            PushNotificationType(rawValue: userInfo["type"] as? String ?? "general") ?? .general
        self.title = title
        self.body = body

        // Исправляем проблему с типами
        var userInfoDict: [String: String] = [:]
        for (key, value) in userInfo {
            if let stringKey = key as? String {
                userInfoDict[stringKey] = "\(value)"
            }
        }
        self.userInfo = userInfoDict
        self.timestamp = Date()
    }
}

// MARK: - App Delegate Extension
extension PushNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        // Показываем уведомление даже когда приложение активно
        completionHandler([.banner, .sound, .badge])

        // Обновляем последнее уведомление
        if let pushNotification = PushNotification(from: notification.request.content.userInfo) {
            DispatchQueue.main.async {
                self.lastNotification = pushNotification
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Обрабатываем действия пользователя
        handleNotificationAction(response.actionIdentifier, userInfo: userInfo)

        completionHandler()
    }

    private func handleNotificationAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any])
    {
        switch actionIdentifier {
        case "FOLLOW_ACTION":
            // Обработка подписки
            if let userId = userInfo["userId"] as? String {
                handleFollowAction(userId: userId)
            }

        case "VIEW_PROFILE_ACTION":
            // Переход к профилю
            if let userId = userInfo["userId"] as? String {
                navigateToProfile(userId: userId)
            }

        case "JOIN_WHEEL_ACTION":
            // Присоединение к колесу
            if let wheelId = userInfo["wheelId"] as? String {
                navigateToWheel(wheelId: wheelId)
            }

        case "VIEW_RESULT_ACTION":
            // Просмотр результата
            if let wheelId = userInfo["wheelId"] as? String {
                navigateToWheelResult(wheelId: wheelId)
            }

        case "OPEN_ACTION":
            // Общее действие открытия
            handleOpenAction(userInfo: userInfo)

        default:
            // Обработка нажатия на уведомление
            handleNotificationTap(userInfo: userInfo)
        }
    }

    private func handleFollowAction(userId: String) {
        // Здесь логика подписки на пользователя
        print("📱 PushNotificationService: Following user \(userId)")
        // Отправляем запрос на сервер
    }

    private func navigateToProfile(userId: String) {
        // Навигация к профилю пользователя
        print("📱 PushNotificationService: Navigating to profile \(userId)")
        NotificationCenter.default.post(
            name: .navigationRequested,
            object: nil,
            userInfo: ["destination": "profile", "userId": userId]
        )
    }

    private func navigateToWheel(wheelId: String) {
        // Навигация к колесу
        print("📱 PushNotificationService: Navigating to wheel \(wheelId)")
        NotificationCenter.default.post(
            name: .navigationRequested,
            object: nil,
            userInfo: ["destination": "wheel", "wheelId": wheelId]
        )
    }

    private func navigateToWheelResult(wheelId: String) {
        // Навигация к результату колеса
        print("📱 PushNotificationService: Navigating to wheel result \(wheelId)")
        NotificationCenter.default.post(
            name: .navigationRequested,
            object: nil,
            userInfo: ["destination": "wheelResult", "wheelId": wheelId]
        )
    }

    private func handleOpenAction(userInfo: [AnyHashable: Any]) {
        // Общая обработка открытия
        print("📱 PushNotificationService: Handling open action")
        handleNotificationTap(userInfo: userInfo)
    }

    private func navigateToChat(chatId: String) {
        // Навигация к чату
        print("📱 PushNotificationService: Navigating to chat \(chatId)")
        NotificationCenter.default.post(
            name: .navigationRequested,
            object: nil,
            userInfo: ["destination": "chat", "chatId": chatId]
        )
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Обработка нажатия на уведомление
        print("📱 PushNotificationService: Notification tapped")

        // Определяем тип уведомления и выполняем соответствующее действие
        if let type = userInfo["type"] as? String {
            switch type {
            case PushNotificationType.newFollower.rawValue:
                if let userId = userInfo["userId"] as? String {
                    navigateToProfile(userId: userId)
                }
            case PushNotificationType.wheelInvitation.rawValue,
                PushNotificationType.wheelResult.rawValue:
                if let wheelId = userInfo["wheelId"] as? String {
                    navigateToWheel(wheelId: wheelId)
                }
            case PushNotificationType.chatMessage.rawValue:
                if let chatId = userInfo["chatId"] as? String {
                    navigateToChat(chatId: chatId)
                }
            default:
                // Общая навигация
                break
            }
        }
    }
}
