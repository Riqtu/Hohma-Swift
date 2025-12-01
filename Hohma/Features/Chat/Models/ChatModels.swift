//
//  ChatModels.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation
import UIKit

// MARK: - Chat Model
struct Chat: Codable, Identifiable, Hashable {
    let id: String
    let type: ChatType
    let name: String?
    let description: String?
    let avatarUrl: String?
    let backgroundUrl: String?
    let createdAt: String
    let updatedAt: String
    let lastMessageAt: String?
    let members: [ChatMember]?
    let messages: [ChatMessage]?
    let unreadCount: Int?  // Приходит из API напрямую

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case description
        case avatarUrl
        case backgroundUrl
        case createdAt
        case updatedAt
        case lastMessageAt
        case members
        case messages
        case unreadCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ChatType.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        backgroundUrl = try container.decodeIfPresent(String.self, forKey: .backgroundUrl)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        lastMessageAt = try container.decodeIfPresent(String.self, forKey: .lastMessageAt)
        members = try container.decodeIfPresent([ChatMember].self, forKey: .members)
        messages = try container.decodeIfPresent([ChatMessage].self, forKey: .messages)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
    }

    // Вычисляемое свойство для отображения названия чата
    var displayName: String {
        if type == .private, let members = members, members.count > 0 {
            // Для приватного чата показываем имя другого участника
            return members.first?.user?.displayName ?? name ?? "Чате"
        }
        return name ?? "Групповой чат"
    }

    // Вычисляемое свойство для аватарки чата
    var displayAvatarUrl: String? {
        if type == .private, let members = members, members.count > 0 {
            // Для приватного чата показываем аватарку другого участника
            let currentUserId = TRPCService.shared.currentUser?.id
            if let otherMember = members.first(where: { $0.userId != currentUserId }) {
                return otherMember.user?.avatarUrl
            }
            return members.first?.user?.avatarUrl
        }
        // Для группового чата показываем аватарку чата
        return avatarUrl
    }

    // Вычисляемое свойство для непрочитанных сообщений
    var unreadCountValue: Int {
        // unreadCount приходит в ответе API напрямую с чатом
        return unreadCount ?? 0
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Chat Type
enum ChatType: String, Codable, CaseIterable {
    case `private` = "PRIVATE"
    case group = "GROUP"
}

// MARK: - Chat Member
struct ChatMember: Codable, Identifiable {
    let id: String
    let chatId: String
    let userId: String
    let role: ChatRole
    let isMuted: Bool
    let notifications: Bool
    let lastReadAt: String?
    let unreadCount: Int
    let joinedAt: String
    let leftAt: String?
    let user: UserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case chatId
        case userId
        case role
        case isMuted
        case notifications
        case lastReadAt
        case unreadCount
        case joinedAt
        case leftAt
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        chatId = try container.decode(String.self, forKey: .chatId)
        userId = try container.decode(String.self, forKey: .userId)
        role = try container.decode(ChatRole.self, forKey: .role)

        // Обработка isMuted и notifications (могут быть Bool или Int)
        if let mutedInt = try? container.decode(Int.self, forKey: .isMuted) {
            isMuted = mutedInt != 0
        } else {
            isMuted = try container.decode(Bool.self, forKey: .isMuted)
        }

        if let notificationsInt = try? container.decode(Int.self, forKey: .notifications) {
            notifications = notificationsInt != 0
        } else {
            notifications = try container.decode(Bool.self, forKey: .notifications)
        }

        lastReadAt = try container.decodeIfPresent(String.self, forKey: .lastReadAt)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        joinedAt = try container.decode(String.self, forKey: .joinedAt)
        leftAt = try container.decodeIfPresent(String.self, forKey: .leftAt)
        user = try container.decodeIfPresent(UserProfile.self, forKey: .user)
    }
}

// MARK: - Chat Role
enum ChatRole: String, Codable, CaseIterable {
    case member = "MEMBER"
    case admin = "ADMIN"
    case owner = "OWNER"
}

// MARK: - Message Reaction
struct MessageReaction: Codable, Identifiable {
    let id: String
    let messageId: String
    let userId: String
    let emoji: String
    let createdAt: String
    let user: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId
        case userId
        case emoji
        case createdAt
        case user
    }
}

extension MessageReaction: Equatable {
    static func == (lhs: MessageReaction, rhs: MessageReaction) -> Bool {
        lhs.id == rhs.id &&
        lhs.messageId == rhs.messageId &&
        lhs.userId == rhs.userId &&
        lhs.emoji == rhs.emoji &&
        lhs.createdAt == rhs.createdAt
    }
}

// MARK: - Chat Message
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let content: String
    let messageType: MessageType
    let attachments: [String]
    let status: MessageStatus
    let replyToId: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    let sender: UserProfile?
    let reactions: [MessageReaction]?
    // replyTo не включаем, чтобы избежать рекурсии в value type - используем только replyToId для связи

    enum CodingKeys: String, CodingKey {
        case id
        case chatId
        case senderId
        case content
        case messageType
        case attachments
        case status
        case replyToId
        case createdAt
        case updatedAt
        case deletedAt
        case sender
        case reactions
        // replyTo исключен из CodingKeys, чтобы избежать рекурсии
    }

    init(
        id: String,
        chatId: String,
        senderId: String,
        content: String,
        messageType: MessageType,
        attachments: [String] = [],
        status: MessageStatus,
        replyToId: String? = nil,
        createdAt: String,
        updatedAt: String,
        deletedAt: String? = nil,
        sender: UserProfile? = nil,
        reactions: [MessageReaction]? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.content = content
        self.messageType = messageType
        self.attachments = attachments
        self.status = status
        self.replyToId = replyToId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.sender = sender
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        chatId = try container.decode(String.self, forKey: .chatId)
        senderId = try container.decode(String.self, forKey: .senderId)
        content = try container.decode(String.self, forKey: .content)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        attachments = try container.decodeIfPresent([String].self, forKey: .attachments) ?? []
        status = try container.decode(MessageStatus.self, forKey: .status)
        replyToId = try container.decodeIfPresent(String.self, forKey: .replyToId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        sender = try container.decodeIfPresent(UserProfile.self, forKey: .sender)
        reactions = try container.decodeIfPresent([MessageReaction].self, forKey: .reactions)
    }
}

extension ChatMessage {
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.deletedAt == rhs.deletedAt &&
        lhs.content == rhs.content &&
        lhs.attachments == rhs.attachments &&
        lhs.status == rhs.status &&
        lhs.reactions == rhs.reactions
    }
}

// MARK: - Message Type
enum MessageType: String, Codable, CaseIterable {
    case text = "TEXT"
    case image = "IMAGE"
    case file = "FILE"
    case sticker = "STICKER"
    case system = "SYSTEM"
}

// MARK: - Chat Attachment (для выбранных файлов перед отправкой)
struct ChatAttachment: Identifiable {
    let id = UUID()
    let image: UIImage?
    let videoURL: URL?
    let thumbnail: UIImage?
    let fileData: Data?
    let fileName: String?
    let fileExtension: String?
    let isVideoMessage: Bool  // Флаг для видеосообщений (кружок), в отличие от обычных видео из галереи
    
    var isImage: Bool {
        return image != nil
    }
    
    var isVideo: Bool {
        return videoURL != nil || (fileExtension?.lowercased() == "mp4" || fileExtension?.lowercased() == "mov")
    }
    
    init(image: UIImage) {
        self.image = image
        self.videoURL = nil
        self.thumbnail = nil
        self.fileData = nil
        self.fileName = nil
        self.fileExtension = nil
        self.isVideoMessage = false
    }
    
    init(videoURL: URL, thumbnail: UIImage? = nil) {
        self.image = nil
        self.videoURL = videoURL
        self.thumbnail = thumbnail
        self.fileData = nil
        self.fileName = nil
        self.fileExtension = videoURL.pathExtension.isEmpty ? "mp4" : videoURL.pathExtension
        self.isVideoMessage = false  // Видео из галереи - не видеосообщение
    }
    
    init(fileData: Data, fileName: String, fileExtension: String, isVideoMessage: Bool = false) {
        self.image = nil
        self.videoURL = nil
        self.thumbnail = nil
        self.fileData = fileData
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isVideoMessage = isVideoMessage
    }
}

// MARK: - Message Status
enum MessageStatus: String, Codable, CaseIterable {
    case sent = "SENT"
    case delivered = "DELIVERED"
    case read = "READ"
}

// MARK: - Chat Request Models
struct CreateChatRequest: Codable {
    let type: ChatType
    let userIds: [String]
    let name: String?
    let description: String?
    let avatarUrl: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "userIds": userIds,
        ]
        if let name = name { dict["name"] = name }
        if let description = description { dict["description"] = description }
        if let avatarUrl = avatarUrl { dict["avatarUrl"] = avatarUrl }
        return dict
    }
}

struct SendMessageRequest: Codable {
    let chatId: String
    let content: String
    let messageType: MessageType
    let attachments: [String]?
    let replyToId: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "chatId": chatId,
            "content": content,
            "messageType": messageType.rawValue,
        ]
        if let attachments = attachments { dict["attachments"] = attachments }
        if let replyToId = replyToId { dict["replyToId"] = replyToId }
        return dict
    }
}

struct UpdateChatRequest: Codable {
    let chatId: String
    let name: String?
    let description: String?
    let avatarUrl: String?
    let backgroundUrl: String?

    var dictionary: [String: Any] {
        var dict: [String: Any] = ["chatId": chatId]
        if let name = name { dict["name"] = name }
        if let description = description { dict["description"] = description }
        if let avatarUrl = avatarUrl { dict["avatarUrl"] = avatarUrl }
        if let backgroundUrl = backgroundUrl { dict["backgroundUrl"] = backgroundUrl }
        return dict
    }
}

// NetworkManager автоматически обрабатывает tRPC формат ответа,
// поэтому дополнительные модели ответов не нужны

