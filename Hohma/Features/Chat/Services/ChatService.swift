//
//  ChatService.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

final class ChatService: TRPCServiceProtocol {
    static let shared = ChatService()
    private init() {}

    // MARK: - Chat Operations

    func getChats(limit: Int = 50, offset: Int = 0, search: String? = nil) async throws -> [Chat] {
        var input: [String: Any] = [
            "limit": limit,
            "offset": offset,
        ]
        if let search = search, !search.isEmpty {
            input["search"] = search
        }
        return try await trpcService.executeGET(endpoint: "chat.getChats", input: input)
    }

    func getChatById(chatId: String) async throws -> Chat {
        let input: [String: Any] = ["chatId": chatId]
        return try await trpcService.executeGET(endpoint: "chat.getChatById", input: input)
    }

    func createChat(_ request: CreateChatRequest) async throws -> Chat {
        return try await trpcService.executePOST(endpoint: "chat.createChat", body: request.dictionary)
    }

    func updateChat(_ request: UpdateChatRequest) async throws -> Chat {
        return try await trpcService.executePOST(endpoint: "chat.updateChat", body: request.dictionary)
    }
    
    func updateChatBackground(chatId: String, backgroundUrl: String?) async throws -> Chat {
        let request = UpdateChatRequest(
            chatId: chatId,
            name: nil,
            description: nil,
            avatarUrl: nil,
            backgroundUrl: backgroundUrl
        )
        return try await trpcService.executePOST(endpoint: "chat.updateChat", body: request.dictionary)
    }

    func leaveChat(chatId: String) async throws {
        let input: [String: Any] = ["chatId": chatId]
        let _: EmptyResponse = try await trpcService.executePOST(endpoint: "chat.leaveChat", body: input)
    }

    // MARK: - Message Operations

    struct PaginatedMessagesResponse: Codable {
        let items: [ChatMessage]
        let hasMore: Bool
        let nextCursor: String?
    }

    func getMessages(
        chatId: String,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> PaginatedMessagesResponse {
        var input: [String: Any] = [
            "chatId": chatId,
            "limit": limit,
        ]
        if let cursor = cursor {
            input["cursor"] = cursor
        }
        return try await trpcService.executeGET(
            endpoint: "chat.getMessages",
            input: input
        )
    }

    func sendMessage(_ request: SendMessageRequest) async throws -> ChatMessage {
        return try await trpcService.executePOST(endpoint: "chat.sendMessage", body: request.dictionary)
    }

    func deleteMessage(messageId: String) async throws {
        let input: [String: Any] = ["messageId": messageId]
        let _: EmptyResponse = try await trpcService.executePOST(endpoint: "chat.deleteMessage", body: input)
    }

    func markAsRead(chatId: String, messageId: String? = nil) async throws {
        var input: [String: Any] = ["chatId": chatId]
        if let messageId = messageId {
            input["messageId"] = messageId
        }
        let _: EmptyResponse = try await trpcService.executePOST(endpoint: "chat.markAsRead", body: input)
    }

    func searchMessages(chatId: String, query: String, limit: Int = 20) async throws -> [ChatMessage] {
        let input: [String: Any] = [
            "chatId": chatId,
            "query": query,
            "limit": limit,
        ]
        return try await trpcService.executeGET(endpoint: "chat.searchMessages", input: input)
    }

    // MARK: - Member Operations

    func addMember(chatId: String, userId: String) async throws -> ChatMember {
        let input: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
        ]
        return try await trpcService.executePOST(endpoint: "chat.addMember", body: input)
    }

    func removeMember(chatId: String, userId: String) async throws {
        let input: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
        ]
        let _: EmptyResponse = try await trpcService.executePOST(endpoint: "chat.removeMember", body: input)
    }
    
    // MARK: - Member Settings Operations
    
    func updateMemberSettings(chatId: String, notifications: Bool? = nil, isMuted: Bool? = nil) async throws -> ChatMember {
        var input: [String: Any] = ["chatId": chatId]
        if let notifications = notifications {
            input["notifications"] = notifications
        }
        if let isMuted = isMuted {
            input["isMuted"] = isMuted
        }
        return try await trpcService.executePOST(endpoint: "chat.updateMemberSettings", body: input)
    }
    
    func updateMemberRole(chatId: String, userId: String, role: ChatRole) async throws -> ChatMember {
        let input: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
            "role": role.rawValue,
        ]
        return try await trpcService.executePOST(endpoint: "chat.updateMemberRole", body: input)
    }
    
    // MARK: - Reaction Operations
    
    func addReaction(messageId: String, emoji: String) async throws -> MessageReaction {
        let body: [String: Any] = [
            "messageId": messageId,
            "emoji": emoji,
        ]
        return try await trpcService.executePOST(endpoint: "chat.addReaction", body: body)
    }
    
    func removeReaction(messageId: String, emoji: String) async throws {
        let body: [String: Any] = [
            "messageId": messageId,
            "emoji": emoji,
        ]
        let _: EmptyResponse = try await trpcService.executePOST(endpoint: "chat.removeReaction", body: body)
    }
}


