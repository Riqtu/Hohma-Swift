//
//  ChatSettingsViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.11.2025.
//

import Foundation
import UIKit

@MainActor
final class ChatSettingsViewModel: ObservableObject {
    @Published var chat: Chat?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isUpdating: Bool = false
    
    // Настройки уведомлений
    @Published var notificationsEnabled: Bool = true
    @Published var isMuted: Bool = false
    
    // Настройки группы
    @Published var chatName: String = ""
    @Published var chatDescription: String = ""
    @Published var selectedAvatarImage: UIImage?
    @Published var selectedBackgroundImage: UIImage?
    @Published var isUploadingAvatar: Bool = false
    @Published var isUploadingBackground: Bool = false
    
    // Участники
    @Published var members: [ChatMember] = []
    @Published var currentUserMember: ChatMember?
    
    // Поиск пользователей для добавления
    @Published var searchQuery: String = ""
    @Published var searchResults: [UserProfile] = []
    @Published var isSearching: Bool = false
    @Published var showAddMemberSheet: Bool = false
    
    private let chatService = ChatService.shared
    private let profileService = ProfileService.shared
    private let chatId: String
    private let currentUserId: String?
    private var searchTask: Task<Void, Never>?
    
    var canEditChat: Bool {
        guard let currentUserMember = currentUserMember else { return false }
        return currentUserMember.role == .admin || currentUserMember.role == .owner
    }
    
    var canModerate: Bool {
        guard let currentUserMember = currentUserMember else { return false }
        return currentUserMember.role == .admin || currentUserMember.role == .owner
    }
    
    var isGroupChat: Bool {
        return chat?.type == .group
    }
    
    var otherUserId: String? {
        guard let chat = chat, chat.type == .private, let members = chat.members else { return nil }
        guard let currentUserId = currentUserId else { return nil }
        return members.first(where: { $0.userId != currentUserId })?.userId
    }
    
    init(chatId: String) {
        self.chatId = chatId
        self.currentUserId = TRPCService.shared.currentUser?.id
    }
    
    func loadChat() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let loadedChat = try await chatService.getChatById(chatId: chatId)
                self.chat = loadedChat
                self.chatName = loadedChat.name ?? ""
                self.chatDescription = loadedChat.description ?? ""
                self.members = loadedChat.members ?? []
                
                // Находим текущего пользователя в участниках
                if let userId = currentUserId {
                    self.currentUserMember = members.first { $0.userId == userId }
                    if let member = currentUserMember {
                        self.notificationsEnabled = member.notifications
                        self.isMuted = member.isMuted
                    }
                }
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to load chat: \(error)", category: .ui)
            }
            
            isLoading = false
        }
    }
    
    func updateNotifications(enabled: Bool) {
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                _ = try await chatService.updateMemberSettings(
                    chatId: chatId,
                    notifications: enabled
                )
                self.notificationsEnabled = enabled
                
                // Обновляем локально
                if currentUserMember != nil {
                    // Обновляем через перезагрузку чата
                    loadChat()
                }
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update notifications: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func updateMuteStatus(muted: Bool) {
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                _ = try await chatService.updateMemberSettings(
                    chatId: chatId,
                    isMuted: muted
                )
                self.isMuted = muted
                
                // Обновляем локально
                loadChat()
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update mute status: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func updateChatName(_ name: String) {
        guard canEditChat else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                let request = UpdateChatRequest(
                    chatId: chatId,
                    name: name.isEmpty ? nil : name,
                    description: nil,
                    avatarUrl: nil,
                    backgroundUrl: nil
                )
                let updatedChat = try await chatService.updateChat(request)
                self.chat = updatedChat
                self.chatName = updatedChat.name ?? ""
                
                // Отправляем уведомление об обновлении
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update chat name: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func updateChatDescription(_ description: String) {
        guard canEditChat else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                let request = UpdateChatRequest(
                    chatId: chatId,
                    name: nil,
                    description: description.isEmpty ? nil : description,
                    avatarUrl: nil,
                    backgroundUrl: nil
                )
                let updatedChat = try await chatService.updateChat(request)
                self.chat = updatedChat
                self.chatDescription = updatedChat.description ?? ""
                
                // Отправляем уведомление об обновлении
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update chat description: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func updateChatAvatar(image: UIImage) {
        guard canEditChat else { return }
        
        Task {
            isUpdating = true
            isUploadingAvatar = true
            errorMessage = nil
            
            do {
                // Загружаем изображение
                let avatarUrl = try await FileUploadService.shared.uploadImage(image)
                
                // Обновляем чат
                let request = UpdateChatRequest(
                    chatId: chatId,
                    name: nil,
                    description: nil,
                    avatarUrl: avatarUrl,
                    backgroundUrl: nil
                )
                let updatedChat = try await chatService.updateChat(request)
                self.chat = updatedChat
                self.selectedAvatarImage = nil
                
                // Отправляем уведомление об обновлении
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update chat avatar: \(error)", category: .ui)
            }
            
            isUploadingAvatar = false
            isUpdating = false
        }
    }
    
    func updateChatBackground(image: UIImage) {
        guard canEditChat else { return }
        
        Task {
            isUpdating = true
            isUploadingBackground = true
            errorMessage = nil
            
            do {
                // Загружаем изображение
                let backgroundUrl = try await FileUploadService.shared.uploadImage(image)
                
                // Обновляем фон чата через API
                let updatedChat = try await chatService.updateChatBackground(
                    chatId: chatId,
                    backgroundUrl: backgroundUrl
                )
                self.chat = updatedChat
                self.selectedBackgroundImage = nil
                
                // Отправляем уведомление об обновлении фона
                NotificationCenter.default.post(
                    name: .chatBackgroundUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
                
                // Отправляем уведомление об обновлении списка чатов
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update chat background: \(error)", category: .ui)
            }
            
            isUploadingBackground = false
            isUpdating = false
        }
    }
    
    func updateMemberRole(userId: String, role: ChatRole) {
        guard canModerate else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                _ = try await chatService.updateMemberRole(
                    chatId: chatId,
                    userId: userId,
                    role: role
                )
                
                // Обновляем локально
                loadChat()
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to update member role: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func removeMember(userId: String) {
        guard canModerate else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                try await chatService.removeMember(chatId: chatId, userId: userId)
                
                // Обновляем локально
                loadChat()
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to remove member: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    // MARK: - Add Member Operations
    
    func searchUsers(query: String) {
        // Отменяем предыдущий поиск
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            await MainActor.run {
                isSearching = true
                errorMessage = nil
            }
            
            do {
                let results = try await profileService.searchUsers(query: query, limit: 20)
                
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }
                
                // Фильтруем пользователей, которые уже в чате
                let memberUserIds = Set(members.filter { $0.leftAt == nil }.map { $0.userId })
                let filteredResults = results.filter { !memberUserIds.contains($0.id) }
                
                await MainActor.run {
                    self.searchResults = filteredResults
                    self.isSearching = false
                }
            } catch {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }
                
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                    isSearching = false
                    AppLogger.shared.error("Failed to search users: \(error)", category: .ui)
                }
            }
        }
    }
    
    func addMember(userId: String) {
        guard canModerate else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                _ = try await chatService.addMember(chatId: chatId, userId: userId)
                
                // Обновляем локально
                loadChat()
                
                // Очищаем поиск
                searchQuery = ""
                searchResults = []
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to add member: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
    
    func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        isSearching = false
    }
    
    func getChatBackgroundUrl() -> String? {
        return chat?.backgroundUrl
    }
    
    func removeChatBackground() {
        guard canEditChat else { return }
        
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                // Удаляем фон чата через API (передаем null)
                let updatedChat = try await chatService.updateChatBackground(
                    chatId: chatId,
                    backgroundUrl: nil
                )
                self.chat = updatedChat
                
                // Отправляем уведомление об обновлении фона
                NotificationCenter.default.post(
                    name: .chatBackgroundUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
                
                // Отправляем уведомление об обновлении списка чатов
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to remove chat background: \(error)", category: .ui)
            }
            
            isUpdating = false
        }
    }
}

