//
//  ChatSocketManager.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

final class ChatSocketManager {
    private let socket: SocketIOServiceAdapter

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
        setupHandlers()
    }

    private func setupHandlers() {
        socket.on(.connect) { _ in
            print("💬 ChatSocketManager: connected")
        }

        socket.on(.chatMessage) { [weak self] data in
            guard let self = self else { return }
            do {
                // Socket.IO отправляет данные в формате: { message: ChatMessage }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let messageDict = json?["message"] as? [String: Any] else {
                    print("❌ ChatSocketManager: chat:message - missing 'message' key in payload")
                    return
                }
                
                let messageData = try JSONSerialization.data(withJSONObject: messageDict)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601withMilliseconds
                let message = try decoder.decode(ChatMessage.self, from: messageData)
                print("💬 ChatSocketManager: chat:message received - \(message.id)")
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
        
        socket.on(.chatListUpdated) { [weak self] data in
            guard let self = self else { return }
            print("💬 ChatSocketManager: chat:list:updated event received, data size: \(data.count)")
            
            // Пробуем распарсить данные разными способами
            var chatId: String?
            
            // Способ 1: Прямой парсинг JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("💬 ChatSocketManager: Parsed as JSON dict: \(json)")
                chatId = json["chatId"] as? String
            } else if let jsonString = String(data: data, encoding: .utf8) {
                print("💬 ChatSocketManager: Data as string: \(jsonString)")
                // Пробуем распарсить строку как JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    chatId = json["chatId"] as? String
                }
            }
            
            if let chatId = chatId {
                print("💬 ChatSocketManager: chat:list:updated - chatId: \(chatId)")
                self.onChatListUpdated?(chatId)
            } else {
                print("❌ ChatSocketManager: chat:list:updated - failed to extract chatId from data")
                print("❌ ChatSocketManager: Raw data: \(data.map { String(format: "%02x", $0) }.joined())")
                // Все равно вызываем callback, чтобы обновить список
                self.onChatListUpdated?("unknown")
            }
        }
    }

    func connectIfNeeded() {
        if !socket.isConnected && !socket.isConnecting {
            socket.connect()
        }
    }

    func joinChat(chatId: String, userId: String) {
        let payload: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
        ]
        socket.emit(.chatJoin, data: payload)
        print("💬 ChatSocketManager: Joining chat \(chatId) for user \(userId)")
    }

    func leaveChat(chatId: String) {
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
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userJoin, data: payload)
        print("💬 ChatSocketManager: Joining user global room for user \(userId)")
    }
    
    func leaveUser(userId: String) {
        let payload: [String: Any] = ["userId": userId]
        socket.emit(.userLeave, data: payload)
        print("💬 ChatSocketManager: Leaving user global room for user \(userId)")
    }
}


