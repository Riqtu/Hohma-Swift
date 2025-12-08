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
        print("💬 ChatSocketManager: Initializing with socket adapter")
        setupHandlers()
        print("💬 ChatSocketManager: Handlers setup completed")
    }

    private func setupHandlers() {
        print("💬 ChatSocketManager: Setting up handlers")
        
        // Регистрируем обработчик события chat:list:updated
        print("💬 ChatSocketManager: Registering chat:list:updated handler")
        socket.on(.chatListUpdated) { [weak self] data in
            guard let self = self else { return }
            print("💬 ChatSocketManager: ===== chat:list:updated event received =====")
            print("💬 ChatSocketManager: Data size: \(data.count) bytes")
            
            // Пробуем распарсить данные разными способами
            var chatId: String?
            
            // Способ 1: Прямой парсинг JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("💬 ChatSocketManager: Parsed as JSON dict: \(json)")
                chatId = json["chatId"] as? String
                if let unreadCount = json["unreadCount"] as? Int {
                    print("💬 ChatSocketManager: unreadCount: \(unreadCount)")
                }
                if let lastMessageAt = json["lastMessageAt"] as? String {
                    print("💬 ChatSocketManager: lastMessageAt: \(lastMessageAt)")
                }
            } else if let jsonString = String(data: data, encoding: .utf8) {
                print("💬 ChatSocketManager: Data as string: \(jsonString)")
                // Пробуем распарсить строку как JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    chatId = json["chatId"] as? String
                    print("💬 ChatSocketManager: Parsed from string, chatId: \(chatId ?? "nil")")
                }
            }
            
            if let chatId = chatId {
                print("💬 ChatSocketManager: chat:list:updated - chatId: \(chatId)")
                print("💬 ChatSocketManager: Calling onChatListUpdated callback")
                self.onChatListUpdated?(chatId)
                print("💬 ChatSocketManager: ===== chat:list:updated processed =====")
            } else {
                print("❌ ChatSocketManager: chat:list:updated - failed to extract chatId from data")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ ChatSocketManager: Raw data as string: \(jsonString)")
                } else {
                    print("❌ ChatSocketManager: Raw data (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                }
                // Все равно вызываем callback, чтобы обновить список
                print("💬 ChatSocketManager: Calling onChatListUpdated with 'unknown'")
                self.onChatListUpdated?("unknown")
            }
        }
        print("💬 ChatSocketManager: chat:list:updated handler registered")
        
        socket.on(.connect) { [weak self] _ in
            print("💬 ChatSocketManager: Socket connected event received")
            guard let self = self else { return }
            
            // Автоматически переприсоединяемся к текущему чату при переподключении
            if let chatId = self.currentChatId,
               let userId = self.currentUserId {
                print("💬 ChatSocketManager: Auto-joining chat \(chatId) after connect")
                // Используем прямой вызов, чтобы избежать рекурсии
                let payload: [String: Any] = [
                    "chatId": chatId,
                    "userId": userId,
                ]
                print("💬 ChatSocketManager: Emitting chat:join event with payload: \(payload)")
                self.socket.emit(.chatJoin, data: payload)
                print("💬 ChatSocketManager: Auto-join event sent for chat \(chatId)")
            } else {
                print("💬 ChatSocketManager: No current chat to auto-join")
            }
            
            // Автоматически переприсоединяемся к глобальной комнате пользователя при переподключении
            if let userId = self.globalRoomUserId {
                print("💬 ChatSocketManager: Auto-joining user global room for user \(userId) after connect")
                let payload: [String: Any] = ["userId": userId]
                self.socket.emit(.userJoin, data: payload)
                print("💬 ChatSocketManager: Auto-join user global room event sent for user \(userId)")
            }
        }

        socket.on(.chatMessage) { [weak self] data in
            guard let self = self else { return }
            print("💬 ChatSocketManager: chat:message event received, data size: \(data.count)")
            do {
                // Socket.IO отправляет данные в формате: { message: ChatMessage }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("💬 ChatSocketManager: Parsed JSON keys: \(json?.keys.joined(separator: ", ") ?? "none")")
                guard let messageDict = json?["message"] as? [String: Any] else {
                    print("❌ ChatSocketManager: chat:message - missing 'message' key in payload")
                    print("❌ ChatSocketManager: Available keys: \(json?.keys.joined(separator: ", ") ?? "none")")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("❌ ChatSocketManager: Raw payload: \(jsonString)")
                    }
                    return
                }
                
                let messageData = try JSONSerialization.data(withJSONObject: messageDict)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601withMilliseconds
                let message = try decoder.decode(ChatMessage.self, from: messageData)
                print("💬 ChatSocketManager: chat:message received and parsed - id: \(message.id), chatId: \(message.chatId), content: \(message.content.prefix(50))")
                self.onNewMessage?(message)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:message payload: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ ChatSocketManager: Raw payload: \(jsonString)")
                }
            }
        }

        socket.on(.chatTyping) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String,
                      let isTyping = json?["isTyping"] as? Bool else {
                    print("❌ ChatSocketManager: chat:typing - missing required fields")
                    return
                }
                print("💬 ChatSocketManager: chat:typing received - userId: \(userId), isTyping: \(isTyping)")
                self.onTyping?(userId, isTyping)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:typing payload: \(error)")
            }
        }

        socket.on(.chatMemberOnline) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String else {
                    print("❌ ChatSocketManager: chat:member:online - missing 'userId' field")
                    return
                }
                print("💬 ChatSocketManager: chat:member:online received - userId: \(userId)")
                self.onMemberOnline?(userId)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:member:online payload: \(error)")
            }
        }

        socket.on(.chatMemberOffline) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let userId = json?["userId"] as? String else {
                    print("❌ ChatSocketManager: chat:member:offline - missing 'userId' field")
                    return
                }
                print("💬 ChatSocketManager: chat:member:offline received - userId: \(userId)")
                self.onMemberOffline?(userId)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:member:offline payload: \(error)")
            }
        }

        socket.on(.chatMessageDeleted) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageId = json?["messageId"] as? String else {
                    print("❌ ChatSocketManager: chat:message:deleted - missing 'messageId' field")
                    return
                }
                print("💬 ChatSocketManager: chat:message:deleted received - messageId: \(messageId)")
                self.onMessageDeleted?(messageId)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:message:deleted payload: \(error)")
            }
        }

        socket.on(.chatUnreadCountUpdated) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let chatId = json?["chatId"] as? String,
                      let userId = json?["userId"] as? String,
                      let unreadCount = json?["unreadCount"] as? Int else {
                    print("❌ ChatSocketManager: chat:unreadCount:updated - missing required fields")
                    return
                }
                print("💬 ChatSocketManager: chat:unreadCount:updated received - chatId: \(chatId), userId: \(userId), unreadCount: \(unreadCount)")
                self.onUnreadCountUpdated?(chatId, userId, unreadCount)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:unreadCount:updated payload: \(error)")
            }
        }
        
        socket.on(.chatMessageReaction) { [weak self] data in
            guard let self = self else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageId = json?["messageId"] as? String,
                      let allReactionsArray = json?["allReactions"] as? [[String: Any]] else {
                    print("❌ ChatSocketManager: chat:message:reaction - missing required fields")
                    return
                }
                
                // Декодируем реакции
                let reactionsData = try JSONSerialization.data(withJSONObject: allReactionsArray)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601withMilliseconds
                let reactions = try decoder.decode([MessageReaction].self, from: reactionsData)
                
                print("💬 ChatSocketManager: chat:message:reaction received - messageId: \(messageId), reactions count: \(reactions.count)")
                self.onMessageReaction?(messageId, reactions)
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:message:reaction payload: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ ChatSocketManager: Raw payload: \(jsonString)")
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
        print("💬 ChatSocketManager: joinChat called - chatId: \(chatId), userId: \(userId)")
        print("💬 ChatSocketManager: Socket state - isConnected: \(socket.isConnected), isConnecting: \(socket.isConnecting)")
        
        // Сохраняем текущий чат для автоматического переприсоединения при переподключении
        self.currentChatId = chatId
        self.currentUserId = userId
        
        // Подключаемся, если еще не подключены
        connectIfNeeded()
        
        // Проверяем, что сокет подключен перед отправкой события
        guard socket.isConnected else {
            print("⚠️ ChatSocketManager: Socket not connected, saved chatId/userId for auto-join on connect")
            // Обработчик connect автоматически присоединит к чату при подключении
            return
        }
        
        // Сокет подключен, отправляем событие сразу
        let payload: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
        ]
        print("💬 ChatSocketManager: Emitting chat:join event with payload: \(payload)")
        socket.emit(.chatJoin, data: payload)
        print("💬 ChatSocketManager: Joining chat \(chatId) for user \(userId) - event sent")
    }

    func leaveChat(chatId: String) {
        // Очищаем текущий чат при выходе
        if currentChatId == chatId {
            currentChatId = nil
            currentUserId = nil
        }
        
        let payload: [String: Any] = ["chatId": chatId]
        socket.emit(.chatLeave, data: payload)
        print("💬 ChatSocketManager: Leaving chat \(chatId)")
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
            print("⚠️ ChatSocketManager: Socket not connected, saved userId for auto-join on connect")
            // Обработчик connect автоматически присоединит к глобальной комнате при подключении
            return
        }
        
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userJoin, data: payload)
        print("💬 ChatSocketManager: Joining user global room for user \(userId)")
    }
    
    func leaveUser(userId: String) {
        // Очищаем сохраненный userId при выходе
        if globalRoomUserId == userId {
            globalRoomUserId = nil
        }
        
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userLeave, data: payload)
        print("💬 ChatSocketManager: Leaving user global room for user \(userId)")
    }
}


