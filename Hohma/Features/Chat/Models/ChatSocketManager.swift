//
//  ChatSocketManager.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

final class ChatSocketManager {
    private let socket: SocketIOServiceAdapter
    
    // Текущий чат для автоматического переприсоединения при переподключении
    private var currentChatId: String?
    private var currentUserId: String?
    // Текущий пользователь для автоматического переприсоединения к глобальной комнате при переподключении
    private var globalRoomUserId: String?

    // Callbacks to VM/UI
    var onNewMessage: ((ChatMessage) -> Void)?
    var onMessageUpdated: ((String, MessageStatus) -> Void)?
    var onMessageDeleted: ((String) -> Void)?  // messageId
    var onTyping: ((String, Bool) -> Void)?  // userId, isTyping
    var onMemberOnline: ((String) -> Void)?  // userId
    var onMemberOffline: ((String) -> Void)?  // userId
    var onUnreadCountUpdated: ((String, String, Int) -> Void)?  // chatId, userId, unreadCount
    var onMessageReaction: ((String, [MessageReaction]) -> Void)?  // messageId, allReactions
    var onChatListUpdated: ((String) -> Void)?  // chatId - для обновления списка чатов

    init(socket: SocketIOServiceAdapter) {
        self.socket = socket
        AppLogger.shared.debug("Initializing with socket adapter", category: .socket)
        setupHandlers()
        AppLogger.shared.debug("Handlers setup completed", category: .socket)
    }

    private func setupHandlers() {
        AppLogger.shared.debug("Setting up handlers", category: .socket)
        
        // Регистрируем обработчик события chat:list:updated
        AppLogger.shared.debug("Registering chat:list:updated handler", category: .socket)
        socket.on(.chatListUpdated) { [weak self] data in
            guard let self = self else { return }
            AppLogger.shared.debug("===== chat:list:updated event received =====", category: .socket)
            AppLogger.shared.debug("Data size: \(data.count) bytes", category: .socket)
            
            // Пробуем распарсить данные разными способами
            var chatId: String?
            
            // Способ 1: Прямой парсинг JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                AppLogger.shared.debug("Parsed as JSON dict: \(json)", category: .socket)
                chatId = json["chatId"] as? String
                if let unreadCount = json["unreadCount"] as? Int {
                    AppLogger.shared.debug("unreadCount: \(unreadCount)", category: .socket)
                }
                if let lastMessageAt = json["lastMessageAt"] as? String {
                    AppLogger.shared.debug("lastMessageAt: \(lastMessageAt)", category: .socket)
                }
            } else if let jsonString = String(data: data, encoding: .utf8) {
                AppLogger.shared.debug("Data as string: \(jsonString)", category: .socket)
                // Пробуем распарсить строку как JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    chatId = json["chatId"] as? String
                    AppLogger.shared.debug("Parsed from string, chatId: \(chatId ?? "nil")", category: .socket)
                }
            }
            
            if let chatId = chatId {
                AppLogger.shared.debug("chat:list:updated - chatId: \(chatId)", category: .socket)
                AppLogger.shared.debug("Calling onChatListUpdated callback", category: .socket)
                self.onChatListUpdated?(chatId)
                AppLogger.shared.debug("===== chat:list:updated processed =====", category: .socket)
            } else {
                AppLogger.shared.error("chat:list:updated - failed to extract chatId from data", category: .socket)
                if let jsonString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("Raw data as string: \(jsonString)", category: .socket)
                } else {
                    AppLogger.shared.error("Raw data (hex): \(data.map { String(format: "%02x", $0) }.joined())", category: .socket)
                }
                // Все равно вызываем callback, чтобы обновить список
                AppLogger.shared.debug("Calling onChatListUpdated with 'unknown'", category: .socket)
                self.onChatListUpdated?("unknown")
            }
        }
        AppLogger.shared.debug("chat:list:updated handler registered", category: .socket)
        
        socket.on(.connect) { [weak self] _ in
            AppLogger.shared.debug("Socket connected event received", category: .socket)
            guard let self = self else { return }
            
            // Автоматически переприсоединяемся к текущему чату при переподключении
            if let chatId = self.currentChatId,
               let userId = self.currentUserId {
                AppLogger.shared.debug("Auto-joining chat \(chatId) after connect", category: .socket)
                // Используем прямой вызов, чтобы избежать рекурсии
                let payload: [String: Any] = [
                    "chatId": chatId,
                    "userId": userId,
                ]
                AppLogger.shared.debug("Emitting chat:join event with payload: \(payload)", category: .socket)
                self.socket.emit(.chatJoin, data: payload)
                AppLogger.shared.debug("Auto-join event sent for chat \(chatId)", category: .socket)
            } else {
                AppLogger.shared.debug("No current chat to auto-join", category: .socket)
            }
            
            // Автоматически переприсоединяемся к глобальной комнате пользователя при переподключении
            if let userId = self.globalRoomUserId {
                AppLogger.shared.debug("Auto-joining user global room for user \(userId) after connect", category: .socket)
                let payload: [String: Any] = ["userId": userId]
                self.socket.emit(.userJoin, data: payload)
                AppLogger.shared.debug("Auto-join user global room event sent for user \(userId)", category: .socket)
            }
        }

        socket.on(.chatMessage) { [weak self] data in
            guard let self = self else { return }
            AppLogger.shared.debug("chat:message event received, data size: \(data.count)", category: .socket)
            do {
                // Socket.IO отправляет данные в формате: { message: ChatMessage }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                AppLogger.shared.debug("Parsed JSON keys: \(json?.keys.joined(separator: ", ") ?? "none")", category: .socket)
                guard let messageDict = json?["message"] as? [String: Any] else {
                    AppLogger.shared.error("chat:message - missing 'message' key in payload", category: .socket)
                    AppLogger.shared.error("Available keys: \(json?.keys.joined(separator: ", ") ?? "none")", category: .socket)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        AppLogger.shared.error("Raw payload: \(jsonString)", category: .socket)
                    }
                    return
                }
                
                let messageData = try JSONSerialization.data(withJSONObject: messageDict)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601withMilliseconds
                let message = try decoder.decode(ChatMessage.self, from: messageData)
                AppLogger.shared.debug("chat:message received and parsed - id: \(message.id), chatId: \(message.chatId), content: \(message.content.prefix(50))", category: .socket)
                self.onNewMessage?(message)
            } catch {
                AppLogger.shared.error("failed to parse chat:message payload: \(error)", category: .socket)
                if let jsonString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("Raw payload: \(jsonString)", category: .socket)
                }
            }
        }

        socket.on(.chatTyping) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String,
                      let isTyping = json?["isTyping"] as? Bool else {
                    AppLogger.shared.error("chat:typing - missing required fields", category: .socket)
                    return
                }
                AppLogger.shared.debug("chat:typing received - userId: \(userId), isTyping: \(isTyping)", category: .socket)
                self.onTyping?(userId, isTyping)
            } catch {
                AppLogger.shared.error("failed to parse chat:typing payload: \(error)", category: .socket)
            }
        }

        socket.on(.chatMemberOnline) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String else {
                    AppLogger.shared.error("chat:member:online - missing 'userId' field", category: .socket)
                    return
                }
                AppLogger.shared.debug("chat:member:online received - userId: \(userId)", category: .socket)
                self.onMemberOnline?(userId)
            } catch {
                AppLogger.shared.error("failed to parse chat:member:online payload: \(error)", category: .socket)
            }
        }

        socket.on(.chatMemberOffline) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String else {
                    AppLogger.shared.error("chat:member:offline - missing 'userId' field", category: .socket)
                    return
                }
                AppLogger.shared.debug("chat:member:offline received - userId: \(userId)", category: .socket)
                self.onMemberOffline?(userId)
            } catch {
                AppLogger.shared.error("failed to parse chat:member:offline payload: \(error)", category: .socket)
            }
        }

        socket.on(.chatMessageDeleted) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageId = json?["messageId"] as? String else {
                    AppLogger.shared.error("chat:message:deleted - missing 'messageId' field", category: .socket)
                    return
                }
                AppLogger.shared.debug("chat:message:deleted received - messageId: \(messageId)", category: .socket)
                self.onMessageDeleted?(messageId)
            } catch {
                AppLogger.shared.error("failed to parse chat:message:deleted payload: \(error)", category: .socket)
            }
        }

        socket.on(.chatUnreadCountUpdated) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let chatId = json?["chatId"] as? String,
                      let userId = json?["userId"] as? String,
                      let unreadCount = json?["unreadCount"] as? Int else {
                    AppLogger.shared.error("chat:unreadCount:updated - missing required fields", category: .socket)
                    return
                }
                AppLogger.shared.debug("chat:unreadCount:updated received - chatId: \(chatId), userId: \(userId), unreadCount: \(unreadCount)", category: .socket)
                self.onUnreadCountUpdated?(chatId, userId, unreadCount)
            } catch {
                AppLogger.shared.error("failed to parse chat:unreadCount:updated payload: \(error)", category: .socket)
            }
        }
        
        socket.on(.chatMessageReaction) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageId = json?["messageId"] as? String,
                      let allReactionsArray = json?["allReactions"] as? [[String: Any]] else {
                    AppLogger.shared.error("chat:message:reaction - missing required fields", category: .socket)
                    return
                }
                
                // Декодируем реакции
                let reactionsData = try JSONSerialization.data(withJSONObject: allReactionsArray)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601withMilliseconds
                let reactions = try decoder.decode([MessageReaction].self, from: reactionsData)
                
                AppLogger.shared.debug("chat:message:reaction received - messageId: \(messageId), reactions count: \(reactions.count)", category: .socket)
                self.onMessageReaction?(messageId, reactions)
            } catch {
                AppLogger.shared.error("failed to parse chat:message:reaction payload: \(error)", category: .socket)
                if let jsonString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("Raw payload: \(jsonString)", category: .socket)
                }
            }
        }
    }

    func connectIfNeeded() {
        if !socket.isConnected && !socket.isConnecting {
            socket.connect()
        }
    }

    func joinChat(chatId: String, userId: String) {
        AppLogger.shared.debug("joinChat called - chatId: \(chatId), userId: \(userId)", category: .socket)
        AppLogger.shared.debug("Socket state - isConnected: \(socket.isConnected), isConnecting: \(socket.isConnecting)", category: .socket)
        
        // Сохраняем текущий чат для автоматического переприсоединения при переподключении
        self.currentChatId = chatId
        self.currentUserId = userId
        
        // Подключаемся, если еще не подключены
        connectIfNeeded()
        
        // Проверяем, что сокет подключен перед отправкой события
        guard socket.isConnected else {
            AppLogger.shared.warning("Socket not connected, saved chatId/userId for auto-join on connect", category: .socket)
            // Обработчик connect автоматически присоединит к чату при подключении
            return
        }
        
        // Сокет подключен, отправляем событие сразу
        let payload: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
        ]
        AppLogger.shared.debug("Emitting chat:join event with payload: \(payload)", category: .socket)
        socket.emit(.chatJoin, data: payload)
        AppLogger.shared.debug("Joining chat \(chatId) for user \(userId) - event sent", category: .socket)
    }

    func leaveChat(chatId: String) {
        // Очищаем текущий чат при выходе
        if currentChatId == chatId {
            currentChatId = nil
            currentUserId = nil
        }
        
        let payload: [String: Any] = ["chatId": chatId]
        socket.emit(.chatLeave, data: payload)
        AppLogger.shared.debug("Leaving chat \(chatId)", category: .socket)
    }

    func sendTyping(chatId: String, isTyping: Bool) {
        let payload: [String: Any] = [
            "chatId": chatId,
            "isTyping": isTyping,
        ]
        socket.emit(.chatTyping, data: payload)
    }
    
    func joinUser(userId: String) {
        // Сохраняем userId для автоматического переприсоединения при переподключении
        self.globalRoomUserId = userId
        
        // Убеждаемся, что сокет подключен перед отправкой события
        connectIfNeeded()
        
        // Проверяем подключение перед отправкой
        guard socket.isConnected else {
            AppLogger.shared.warning("Socket not connected, saved userId for auto-join on connect", category: .socket)
            // Обработчик connect автоматически присоединит к глобальной комнате при подключении
            return
        }
        
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userJoin, data: payload)
        AppLogger.shared.debug("Joining user global room for user \(userId)", category: .socket)
    }
    
    func leaveUser(userId: String) {
        // Очищаем сохраненный userId при выходе
        if globalRoomUserId == userId {
            globalRoomUserId = nil
        }
        
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userLeave, data: payload)
        AppLogger.shared.debug("Leaving user global room for user \(userId)", category: .socket)
    }
}


