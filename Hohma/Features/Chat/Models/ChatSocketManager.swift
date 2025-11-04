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
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messageDict = json["message"] as? [String: Any],
                   let messageData = try? JSONSerialization.data(withJSONObject: messageDict)
                {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601withMilliseconds
                    let message = try decoder.decode(ChatMessage.self, from: messageData)
                    print("💬 ChatSocketManager: chat:message received - \(message.id)")
                    self.onNewMessage?(message)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:message payload: \(error)")
            }
        }

        socket.on(.chatTyping) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userId = json["userId"] as? String,
                   let isTyping = json["isTyping"] as? Bool
                {
                    print("💬 ChatSocketManager: chat:typing received - userId: \(userId), isTyping: \(isTyping)")
                    self.onTyping?(userId, isTyping)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:typing payload: \(error)")
            }
        }

        socket.on(.chatMemberOnline) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userId = json["userId"] as? String
                {
                    print("💬 ChatSocketManager: chat:member:online received - userId: \(userId)")
                    self.onMemberOnline?(userId)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:member:online payload: \(error)")
            }
        }

        socket.on(.chatMemberOffline) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userId = json["userId"] as? String
                {
                    print("💬 ChatSocketManager: chat:member:offline received - userId: \(userId)")
                    self.onMemberOffline?(userId)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:member:offline payload: \(error)")
            }
        }

        socket.on(.chatMessageDeleted) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messageId = json["messageId"] as? String
                {
                    print("💬 ChatSocketManager: chat:message:deleted received - messageId: \(messageId)")
                    self.onMessageDeleted?(messageId)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:message:deleted payload: \(error)")
            }
        }

        socket.on(.chatUnreadCountUpdated) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let chatId = json["chatId"] as? String,
                   let userId = json["userId"] as? String,
                   let unreadCount = json["unreadCount"] as? Int
                {
                    print("💬 ChatSocketManager: chat:unreadCount:updated received - chatId: \(chatId), userId: \(userId), unreadCount: \(unreadCount)")
                    self.onUnreadCountUpdated?(chatId, userId, unreadCount)
                }
            } catch {
                print("❌ ChatSocketManager: failed to parse chat:unreadCount:updated payload: \(error)")
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
}


