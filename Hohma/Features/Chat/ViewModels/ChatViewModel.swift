//
//  ChatViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var chat: Chat?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMessages: Bool = false
    @Published var isLoadingMoreMessages: Bool = false  // Для загрузки предыдущих сообщений
    @Published var hasMoreMessages: Bool = true  // Есть ли еще сообщения для загрузки
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var isTyping: Bool = false
    @Published var typingUsers: Set<String> = []  // Set of userIds who are typing
    @Published var messageInput: String = ""
    @Published var selectedAttachments: [ChatAttachment] = []  // Выбранные файлы для отправки
    @Published var isUploadingAttachments: Bool = false
    @Published var isRecordingVoice: Bool = false
    @Published var voiceRecordingDuration: TimeInterval = 0
    @Published var voiceAudioLevel: Float = 0.0
    @Published var isCancelingVoice: Bool = false
    @Published var isRecordingVideo: Bool = false
    @Published var videoRecordingDuration: TimeInterval = 0
    @Published var isCancelingVideo: Bool = false
    @Published var showVideoControls: Bool = false  // Показывать ли overlay с кнопками управления
    @Published var replyingToMessage: ChatMessage? = nil  // Сообщение, на которое отвечаем
    @Published var showStickerPicker: Bool = false  // Показывать ли панель выбора стикеров

    private let chatService = ChatService.shared
    private let stickerService = StickerService.shared
    private let audioRecorder = AudioRecorderService()
    let videoRecorder = VideoRecorderService()  // Public для доступа из View
    private var chatSocketManager: ChatSocketManager?
    private var socketAdapter: SocketIOServiceAdapter?
    private var chatId: String?
    private var typingTimer: Timer?
    private var lastTypingTime: Date?
    private var recordingSyncTask: Task<Void, Never>?
    private let messagesPageSize = 30  // Размер страницы при загрузке
    private var nextMessagesCursor: String? = nil
    private var messageIds: Set<String> = [] // Для быстрой проверки дубликатов
    private var pendingMessages: [String: String] = [:] // Временные ID -> реальные ID
    
    // MARK: - Helper Methods
    
    private func convertAuthUserToUserProfile(_ authUser: AuthUser?) -> UserProfile? {
        guard let authUser = authUser else { return nil }
        return UserProfile(
            id: authUser.id,
            name: authUser.name,
            username: authUser.username,
            firstName: authUser.firstName,
            lastName: authUser.lastName,
            avatarUrl: authUser.avatarUrl?.absoluteString,
            email: authUser.email,
            coins: authUser.coins,
            clicks: authUser.clicks
        )
    }
    
    private func formatDateForMessage(_ date: Date) -> String {
        // Используем тот же формат, что и сервер: "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.string(from: date)
    }

    init() {
        setupSocketAdapter()
        setupAudioRecorderBinding()
        setupVideoRecorderBinding()
    }
    
    private func setupAudioRecorderBinding() {
        // Синхронизируем состояние из AudioRecorderService
        recordingSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                // Проверяем, что задача не отменена перед каждым обновлением
                guard !Task.isCancelled else { break }
                
                if self.audioRecorder.isRecording {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.isRecordingVoice = true
                        self.voiceRecordingDuration = self.audioRecorder.recordingDuration
                        self.voiceAudioLevel = self.audioRecorder.audioLevel
                    }
                } else if self.isRecordingVoice {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.isRecordingVoice = false
                        self.voiceRecordingDuration = 0
                        self.voiceAudioLevel = 0.0
                    }
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 секунды
            }
        }
    }
    
    deinit {
        recordingSyncTask?.cancel()
        videoRecordingSyncTask?.cancel()
        typingTimer?.invalidate()
        // Очищаем ресурсы синхронно в deinit
        // leaveChat() вызываем через прямой вызов, так как manager не требует MainActor
        if let chatId = chatId, let manager = chatSocketManager {
            manager.leaveChat(chatId: chatId)
        }
    }

    // MARK: - Socket Setup

    private func setupSocketAdapter() {
        guard let authToken = TRPCService.shared.authToken else {
            print("❌ ChatViewModel: No auth token available")
            return
        }

        // Используем тот же подход, что и в RaceViewModel
        socketAdapter = SocketIOServiceAdapter(authToken: authToken)
        socketAdapter?.connect()

        guard let adapter = socketAdapter else {
            print("❌ ChatViewModel: Failed to create SocketAdapter")
            return
        }

        chatSocketManager = ChatSocketManager(socket: adapter)
        setupSocketCallbacks()
    }

    private func setupSocketCallbacks() {
        guard let manager = chatSocketManager else { return }

        manager.onNewMessage = { [weak self] message in
            guard let self = self else { return }
            Task { @MainActor in
                // Проверяем, не является ли это сообщение заменой временного
                // Ищем временное сообщение от того же пользователя с похожим содержимым
                if message.senderId == self.currentUserId,
                   let tempIndex = self.messages.firstIndex(where: { tempMessage in
                       tempMessage.id.hasPrefix("temp-") &&
                       tempMessage.senderId == message.senderId &&
                       tempMessage.content == message.content &&
                       tempMessage.messageType == message.messageType &&
                       tempMessage.attachments == message.attachments
                   }) {
                    // Заменяем временное сообщение на реальное
                    let tempMessageId = self.messages[tempIndex].id
                    self.messages[tempIndex] = message
                    self.messageIds.remove(tempMessageId)
                    self.messageIds.insert(message.id)
                    self.messages.sort { $0.createdAt < $1.createdAt }
                    
                    // Отправляем уведомление об обновлении списка чатов
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": message.chatId]
                    )
                } else if !self.messageIds.contains(message.id) {
                    // Добавляем сообщение только если его еще нет
                    self.messageIds.insert(message.id)
                    self.messages.append(message)
                    self.messages.sort { $0.createdAt < $1.createdAt }
                    
                    // Отправляем уведомление об обновлении списка чатов
                    // Это обновит счетчик непрочитанных в других чатах
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": message.chatId]
                    )
                }
            }
        }

        manager.onTyping = { [weak self] userId, isTyping in
            guard let self = self else { return }
            Task { @MainActor in
                if isTyping {
                    self.typingUsers.insert(userId)
                } else {
                    self.typingUsers.remove(userId)
                }
            }
        }

        manager.onMemberOnline = { userId in
            print("💬 ChatViewModel: Member \(userId) came online")
        }

        manager.onMemberOffline = { userId in
            print("💬 ChatViewModel: Member \(userId) went offline")
        }

        manager.onMessageDeleted = { [weak self] messageId in
            guard let self = self else { return }
            Task { @MainActor in
                // Удаляем сообщение из списка при получении события через Socket.IO
                self.messages.removeAll { $0.id == messageId }
                self.messageIds.remove(messageId)
            }
        }
        
        manager.onUnreadCountUpdated = { [weak self] chatId, userId, unreadCount in
            guard let self = self else { return }
            Task { @MainActor in
                // Обновляем счетчик непрочитанных для текущего чата
                if chatId == self.chatId {
                    // Отправляем уведомление об обновлении списка чатов
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": chatId]
                    )
                }
            }
        }
        
        manager.onMessageReaction = { [weak self] messageId, reactions in
            guard let self = self else { return }
            Task { @MainActor in
                // Обновляем реакции для сообщения
                if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                    let updatedMessage = self.messages[index]
                    // Создаем новое сообщение с обновленными реакциями
                    let updatedChatMessage = ChatMessage(
                        id: updatedMessage.id,
                        chatId: updatedMessage.chatId,
                        senderId: updatedMessage.senderId,
                        content: updatedMessage.content,
                        messageType: updatedMessage.messageType,
                        attachments: updatedMessage.attachments,
                        status: updatedMessage.status,
                        replyToId: updatedMessage.replyToId,
                        createdAt: updatedMessage.createdAt,
                        updatedAt: updatedMessage.updatedAt,
                        deletedAt: updatedMessage.deletedAt,
                        sender: updatedMessage.sender,
                        reactions: reactions
                    )
                    self.messages[index] = updatedChatMessage
                }
            }
        }
    }

    // MARK: - Chat Loading

    func loadChat(chatId: String) {
        self.chatId = chatId

        Task {
            isLoading = true
            errorMessage = nil

            do {
                let loadedChat = try await chatService.getChatById(chatId: chatId)
                await MainActor.run {
                    self.chat = loadedChat
                    print("💬 ChatViewModel: Chat loaded - backgroundUrl: \(loadedChat.backgroundUrl ?? "nil"), avatarUrl: \(loadedChat.avatarUrl ?? "nil")")
                    loadMessages()

                    // Присоединяемся к комнате чата через Socket.IO
                    joinChat()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    print("❌ ChatViewModel: Failed to load chat: \(error)")
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    func loadMessages() {
        guard let chatId = chatId else { return }

        Task {
            isLoadingMessages = true
            hasMoreMessages = true  // Сбрасываем флаг при новой загрузке
            nextMessagesCursor = nil

            do {
                let response = try await chatService.getMessages(
                    chatId: chatId,
                    limit: messagesPageSize,
                    cursor: nil
                )
                let loadedMessages = response.items
                self.messages = loadedMessages.sorted { $0.createdAt < $1.createdAt }
                // Обновляем Set для быстрой проверки дубликатов
                self.messageIds = Set(loadedMessages.map { $0.id })
                
                hasMoreMessages = response.hasMore
                nextMessagesCursor = response.hasMore ? response.nextCursor : nil

                // Отмечаем как прочитанное
                markAsRead()
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to load messages: \(error)")
            }

            isLoadingMessages = false
        }
    }

    // MARK: - Load More Messages (Pagination)
    
    func loadMoreMessages() {
        guard let chatId = chatId,
              !isLoadingMoreMessages,
              !isLoadingMessages,
              hasMoreMessages,
              let cursor = nextMessagesCursor
        else { return }

        Task {
            isLoadingMoreMessages = true

            do {
                let response = try await chatService.getMessages(
                    chatId: chatId,
                    limit: messagesPageSize,
                    cursor: cursor
                )
                
                hasMoreMessages = response.hasMore
                nextMessagesCursor = response.hasMore ? response.nextCursor : nil
                
                let loadedMessages = response.items
                guard !loadedMessages.isEmpty else {
                    isLoadingMoreMessages = false
                    return
                }
                
                // Добавляем новые сообщения в начало списка и сортируем
                let combinedMessages = (loadedMessages + messages).sorted { $0.createdAt < $1.createdAt }
                
                // Убираем дубликаты по ID
                var uniqueMessages: [ChatMessage] = []
                var seenIds: Set<String> = []
                for message in combinedMessages {
                    if !seenIds.contains(message.id) {
                        uniqueMessages.append(message)
                        seenIds.insert(message.id)
                    }
                }
                
                self.messages = uniqueMessages.sorted { $0.createdAt < $1.createdAt }
                // Обновляем Set для быстрой проверки дубликатов
                self.messageIds = seenIds
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to load more messages: \(error)")
            }

            isLoadingMoreMessages = false
        }
    }

    // MARK: - Socket Operations

    private func joinChat() {
        guard let chatId = chatId,
              let userId = currentUserId,
              let manager = chatSocketManager
        else {
            print("❌ ChatViewModel: Cannot join chat - missing chatId or userId")
            return
        }

        manager.connectIfNeeded()
        manager.joinChat(chatId: chatId, userId: userId)
    }

    func leaveChat() {
        guard let chatId = chatId,
              let manager = chatSocketManager
        else { return }

        manager.leaveChat(chatId: chatId)
        typingTimer?.invalidate()
    }

    // MARK: - Message Operations

    func sendMessage() {
        guard let chatId = chatId,
              (!messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedAttachments.isEmpty),
              !isSending
        else { return }

        let content = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentsToUpload = selectedAttachments
        
        // Сохраняем сообщение для ответа перед очисткой для возможного восстановления при ошибке
        let savedReplyingToMessage = replyingToMessage
        
        // Создаем временное сообщение для оптимистичного обновления
        let tempMessageId = "temp-\(UUID().uuidString)"
        let now = formatDateForMessage(Date())
        
        // Разделяем видеосообщения и обычные вложения
        let videoMessages = attachmentsToUpload.filter { $0.isVideoMessage }
        let regularAttachments = attachmentsToUpload.filter { !$0.isVideoMessage }
        
        // Определяем тип сообщения заранее (для временного сообщения)
        let messageType: MessageType
        if !regularAttachments.isEmpty {
            let allImages = regularAttachments.allSatisfy { $0.isImage }
            let hasVideos = regularAttachments.contains { $0.isVideo }
            // Если есть фото или видео (или оба) - используем IMAGE для альбомов
            messageType = (allImages || hasVideos) ? .image : .file
        } else {
            messageType = .text
        }
        
        // Создаем временное сообщение только для обычных вложений или текста
        // Видеосообщения отправляются без временного сообщения
        var tempMessage: ChatMessage? = nil
        if !regularAttachments.isEmpty || (!content.isEmpty && videoMessages.isEmpty) {
            tempMessage = ChatMessage(
                id: tempMessageId,
                chatId: chatId,
                senderId: currentUserId ?? "",
                content: content.isEmpty ? (messageType == .image ? (regularAttachments.count > 1 ? "Альбом" : "Фото") : "Файл") : content,
                messageType: messageType,
                attachments: [], // Вложения будут добавлены после загрузки
                status: .sent, // Временно показываем как отправленное
                replyToId: savedReplyingToMessage?.id,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sender: convertAuthUserToUserProfile(TRPCService.shared.currentUser),
                reactions: nil
            )
            
            // Добавляем временное сообщение сразу в список
            if let tempMsg = tempMessage {
                messageIds.insert(tempMessageId)
                messages.append(tempMsg)
                messages.sort { $0.createdAt < $1.createdAt }
            }
        }
        
        // Очищаем input после добавления временного сообщения
        messageInput = ""
        selectedAttachments = []
        replyingToMessage = nil
        
        Task {
            isSending = true
            isUploadingAttachments = !attachmentsToUpload.isEmpty
            errorMessage = nil

            do {
                // Сначала отправляем видеосообщения отдельно (каждое отдельным сообщением)
                for videoMessage in videoMessages {
                    let videoURLs = try await uploadAttachments([videoMessage])
                    guard let videoURL = videoURLs.first else { continue }
                    
                    let request = SendMessageRequest(
                        chatId: chatId,
                        content: "Видеосообщение",
                        messageType: .file,
                        attachments: [videoURL],
                        replyToId: savedReplyingToMessage?.id
                    )
                    
                    let sentMessage = try await chatService.sendMessage(request)
                    if !messageIds.contains(sentMessage.id) {
                        messageIds.insert(sentMessage.id)
                        messages.append(sentMessage)
                        messages.sort { $0.createdAt < $1.createdAt }
                    }
                    
                    // Отправляем уведомление для обновления списка чатов
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": chatId]
                    )
                }
                
                // Затем отправляем обычные вложения (фото/видео из галереи) как альбом
                if !regularAttachments.isEmpty {
                    let attachmentURLs = try await uploadAttachments(regularAttachments)
                    
                    // Обновляем временное сообщение с загруженными вложениями
                    if let tempMsg = tempMessage, let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                        let updatedTempMessage = ChatMessage(
                            id: tempMessageId,
                            chatId: chatId,
                            senderId: currentUserId ?? "",
                            content: content.isEmpty ? (regularAttachments.count > 1 ? "Альбом" : "Фото") : content,
                            messageType: messageType,
                            attachments: attachmentURLs,
                            status: .sent,
                            replyToId: savedReplyingToMessage?.id,
                            createdAt: tempMsg.createdAt,
                            updatedAt: formatDateForMessage(Date()),
                            deletedAt: nil,
                            sender: convertAuthUserToUserProfile(TRPCService.shared.currentUser),
                            reactions: nil
                        )
                        messages[tempIndex] = updatedTempMessage
                    }
                    
                    let request = SendMessageRequest(
                        chatId: chatId,
                        content: content.isEmpty ? (regularAttachments.count > 1 ? "Альбом" : "Фото") : content,
                        messageType: messageType,
                        attachments: attachmentURLs,
                        replyToId: savedReplyingToMessage?.id
                    )

                    let sentMessage = try await chatService.sendMessage(request)
                    
                    // Заменяем временное сообщение на реальное
                    if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                        messages[tempIndex] = sentMessage
                        messageIds.remove(tempMessageId)
                        messageIds.insert(sentMessage.id)
                        messages.sort { $0.createdAt < $1.createdAt }
                    } else {
                        // Если временное сообщение не найдено, просто добавляем реальное
                        if !messageIds.contains(sentMessage.id) {
                            messageIds.insert(sentMessage.id)
                            messages.append(sentMessage)
                            messages.sort { $0.createdAt < $1.createdAt }
                        }
                    }
                    
                    // Отправляем уведомление для обновления списка чатов
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": chatId]
                    )
                } else if !content.isEmpty && videoMessages.isEmpty {
                    // Текстовое сообщение, если нет вложений
                    // Обновляем временное сообщение
                    if let tempMsg = tempMessage, let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                        let updatedTempMessage = ChatMessage(
                            id: tempMessageId,
                            chatId: chatId,
                            senderId: currentUserId ?? "",
                            content: content,
                            messageType: .text,
                            attachments: [],
                            status: .sent,
                            replyToId: savedReplyingToMessage?.id,
                            createdAt: tempMsg.createdAt,
                            updatedAt: formatDateForMessage(Date()),
                            deletedAt: nil,
                            sender: convertAuthUserToUserProfile(TRPCService.shared.currentUser),
                            reactions: nil
                        )
                        messages[tempIndex] = updatedTempMessage
                    }
                    
                    let request = SendMessageRequest(
                        chatId: chatId,
                        content: content,
                        messageType: .text,
                        attachments: nil,
                        replyToId: savedReplyingToMessage?.id
                    )
                    
                    let sentMessage = try await chatService.sendMessage(request)
                    
                    // Заменяем временное сообщение на реальное
                    if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                        messages[tempIndex] = sentMessage
                        messageIds.remove(tempMessageId)
                        messageIds.insert(sentMessage.id)
                        messages.sort { $0.createdAt < $1.createdAt }
                    } else {
                        if !messageIds.contains(sentMessage.id) {
                            messageIds.insert(sentMessage.id)
                            messages.append(sentMessage)
                            messages.sort { $0.createdAt < $1.createdAt }
                        }
                    }
                    
                    // Отправляем уведомление для обновления списка чатов
                    NotificationCenter.default.post(
                        name: .chatListUpdated,
                        object: nil,
                        userInfo: ["chatId": chatId]
                    )
                } else if videoMessages.isEmpty && regularAttachments.isEmpty {
                    // Удаляем временное сообщение, если нет вложений и текста
                    if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                        messages.remove(at: tempIndex)
                        messageIds.remove(tempMessageId)
                    }
                }

                // Останавливаем индикатор печати
                stopTyping()
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to send message: \(error)")
                
                // Удаляем временное сообщение при ошибке
                if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                    messages.remove(at: tempIndex)
                    messageIds.remove(tempMessageId)
                }
                
                // Восстанавливаем текст сообщения и сообщение для ответа при ошибке
                messageInput = content
                selectedAttachments = attachmentsToUpload
                replyingToMessage = savedReplyingToMessage
            }

            isSending = false
            isUploadingAttachments = false
        }
    }
    
    // MARK: - Sticker Operations
    
    func sendSticker(stickerUrl: String, packId: String) {
        guard let chatId = chatId, !isSending else { return }
        
        // Создаем временное сообщение для оптимистичного обновления
        let tempMessageId = "temp-\(UUID().uuidString)"
        let now = formatDateForMessage(Date())
        let savedReplyingToMessage = replyingToMessage
        
        let tempMessage = ChatMessage(
            id: tempMessageId,
            chatId: chatId,
            senderId: currentUserId ?? "",
            content: "",
            messageType: .sticker,
            attachments: [stickerUrl],
            status: .sent,
            replyToId: savedReplyingToMessage?.id,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            sender: convertAuthUserToUserProfile(TRPCService.shared.currentUser),
            reactions: nil
        )
        
        // Добавляем временное сообщение сразу
        messageIds.insert(tempMessageId)
        messages.append(tempMessage)
        messages.sort { $0.createdAt < $1.createdAt }
        
        replyingToMessage = nil
        showStickerPicker = false
        
        Task {
            isSending = true
            errorMessage = nil
            
            do {
                let request = SendMessageRequest(
                    chatId: chatId,
                    content: "",
                    messageType: .sticker,
                    attachments: [stickerUrl],
                    replyToId: savedReplyingToMessage?.id
                )
                
                let sentMessage = try await chatService.sendMessage(request)
                
                // Заменяем временное сообщение на реальное
                if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                    messages[tempIndex] = sentMessage
                    messageIds.remove(tempMessageId)
                    messageIds.insert(sentMessage.id)
                    messages.sort { $0.createdAt < $1.createdAt }
                } else {
                    if !messageIds.contains(sentMessage.id) {
                        messageIds.insert(sentMessage.id)
                        messages.append(sentMessage)
                        messages.sort { $0.createdAt < $1.createdAt }
                    }
                }
                
                // Отправляем уведомление для обновления списка чатов
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to send sticker: \(error)")
                
                // Удаляем временное сообщение при ошибке
                if let tempIndex = messages.firstIndex(where: { $0.id == tempMessageId }) {
                    messages.remove(at: tempIndex)
                    messageIds.remove(tempMessageId)
                }
                
                replyingToMessage = savedReplyingToMessage
            }
            
            isSending = false
        }
    }
    
    // MARK: - Attachment Operations
    
    func addAttachment(_ attachment: ChatAttachment) {
        // Максимум 10 вложений
        if selectedAttachments.count < 10 {
            selectedAttachments.append(attachment)
        }
    }
    
    func removeAttachment(at index: Int) {
        guard index < selectedAttachments.count else { return }
        selectedAttachments.remove(at: index)
    }
    
    func removeAllAttachments() {
        selectedAttachments.removeAll()
    }
    
    private func uploadAttachments(_ attachments: [ChatAttachment]) async throws -> [String] {
        var uploadedURLs: [String] = []
        
        for attachment in attachments {
            let url: String
            
            if let image = attachment.image {
                // Загружаем изображение
                url = try await FileUploadService.shared.uploadImage(image)
            } else if let videoURL = attachment.videoURL {
                // Загружаем видео
                let videoData = try Data(contentsOf: videoURL)
                let fileExtension = attachment.fileExtension ?? "mp4"
                let mimeType = FileUploadService.getMimeType(for: fileExtension)
                let fullFileName = "chat/\(UUID().uuidString).\(fileExtension)"
                url = try await FileUploadService.shared.uploadFile(
                    fileData: videoData,
                    fileName: fullFileName,
                    mimeType: mimeType
                )
            } else if let fileData = attachment.fileData {
                // Загружаем файл
                let fileExtension = attachment.fileExtension ?? "bin"
                let mimeType = FileUploadService.getMimeType(for: fileExtension)
                let fullFileName = "chat/\(UUID().uuidString).\(fileExtension)"
                url = try await FileUploadService.shared.uploadFile(
                    fileData: fileData,
                    fileName: fullFileName,
                    mimeType: mimeType
                )
            } else {
                continue
            }
            
            uploadedURLs.append(url)
        }
        
        return uploadedURLs
    }

    func deleteMessage(messageId: String) {
        Task {
            do {
                try await chatService.deleteMessage(messageId: messageId)
                messages.removeAll { $0.id == messageId }
                messageIds.remove(messageId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func markAsRead() {
        guard let chatId = chatId else { return }

        Task {
            do {
                try await chatService.markAsRead(chatId: chatId, messageId: nil)
                // Отправляем уведомление об обновлении списка чатов
                NotificationCenter.default.post(
                    name: .chatListUpdated,
                    object: nil,
                    userInfo: ["chatId": chatId]
                )
            } catch {
                print("❌ ChatViewModel: Failed to mark as read: \(error)")
            }
        }
    }

    // MARK: - Typing Indicator

    func startTyping() {
        guard let chatId = chatId else { return }

        // Отправляем событие печати только если прошло больше 2 секунд с последнего
        let now = Date()
        if let lastTime = lastTypingTime, now.timeIntervalSince(lastTime) < 2.0 {
            return
        }
        lastTypingTime = now

        chatSocketManager?.sendTyping(chatId: chatId, isTyping: true)

        // Автоматически останавливаем индикатор через 3 секунды
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopTyping()
            }
        }
    }

    func stopTyping() {
        guard let chatId = chatId else { return }
        chatSocketManager?.sendTyping(chatId: chatId, isTyping: false)
        typingTimer?.invalidate()
    }
    
    // MARK: - Voice Recording
    
    func startVoiceRecording() {
        guard !isRecordingVoice else { return }
        
        guard audioRecorder.startRecording() != nil else {
            errorMessage = "Не удалось начать запись"
            return
        }
        
        // Состояние синхронизируется через setupAudioRecorderBinding
    }
    
    func stopVoiceRecording() {
        guard isRecordingVoice else { return }
        
        guard let audioData = audioRecorder.stopRecording() else {
            isRecordingVoice = false
            errorMessage = "Не удалось сохранить запись"
            return
        }
        
        isRecordingVoice = false
        voiceRecordingDuration = 0
        voiceAudioLevel = 0.0
        
        // Проверяем минимальную длительность (0.5 секунды)
        guard audioData.count > 1000 else {
            errorMessage = "Запись слишком короткая"
            return
        }
        
        // Создаем attachment для голосового сообщения
        let voiceAttachment = ChatAttachment(
            fileData: audioData,
            fileName: "voice_message.m4a",
            fileExtension: "m4a"
        )
        
        // Добавляем к вложениям и отправляем
        addAttachment(voiceAttachment)
        
        Task {
            // Небольшая задержка для визуализации
            try? await Task.sleep(nanoseconds: 300_000_000)
            sendMessage()
        }
    }
    
    func cancelVoiceRecording() {
        guard isRecordingVoice else { return }
        
        audioRecorder.cancelRecording()
        isRecordingVoice = false
        voiceRecordingDuration = 0
        voiceAudioLevel = 0.0
        isCancelingVoice = false
    }
    
    // MARK: - Video Recording
    
    func startVideoRecording() {
        guard !isRecordingVideo else { return }
        
        videoRecorder.requestPermissions { [weak self] granted in
            guard granted else {
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Нужно разрешение на камеру и микрофон"
                }
                return
            }
            
            guard let self = self else { return }
            
            // Запускаем сессию сначала
            self.videoRecorder.startSession()
            
            // Небольшая задержка для запуска сессии
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task { @MainActor in
                    guard let _ = self.videoRecorder.startRecording() else {
                        self.errorMessage = "Не удалось начать запись видео"
                        self.videoRecorder.stopSession()
                        return
                    }
                    
                    // Синхронизируем состояние
                    self.isRecordingVideo = true
                    self.videoRecordingDuration = 0
                    self.isCancelingVideo = false
                    self.showVideoControls = false
                }
            }
        }
    }
    
    func stopVideoRecording() {
        guard isRecordingVideo else { return }
        
        let durationToCheck = videoRecordingDuration  // Сохраняем длительность перед остановкой
        
        videoRecorder.stopRecording { [weak self] videoData in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.isRecordingVideo = false
                self.videoRecordingDuration = 0
                self.isCancelingVideo = false
                self.showVideoControls = false  // Скрываем кнопки управления
                
                self.videoRecorder.stopSession()
                
                guard let data = videoData else {
                    self.errorMessage = "Не удалось сохранить видео"
                    return
                }
                
                // Проверяем минимальную длительность (0.5 секунды)
                guard durationToCheck > 0.5 else {
                    self.errorMessage = "Видео слишком короткое"
                    return
                }
                
                // Создаем attachment для видеосообщения
                let videoAttachment = ChatAttachment(
                    fileData: data,
                    fileName: "video_message.mp4",
                    fileExtension: "mp4",
                    isVideoMessage: true  // Помечаем как видеосообщение
                )
                
                // Добавляем к вложениям и отправляем
                self.addAttachment(videoAttachment)
                
                // Небольшая задержка для визуализации
                try? await Task.sleep(nanoseconds: 300_000_000)
                self.sendMessage()
            }
        }
    }
    
    func cancelVideoRecording() {
        guard isRecordingVideo else { return }
        
        videoRecorder.cancelRecording()
        videoRecorder.stopSession()
        isRecordingVideo = false
        videoRecordingDuration = 0
        isCancelingVideo = false
        showVideoControls = false
    }
    
    func switchVideoCamera() {
        guard isRecordingVideo else {
            // Если не идет запись, переключаем камеру обычным способом
            videoRecorder.switchCamera()
            return
        }
        // Если идет запись, используем специальный метод
        videoRecorder.switchCameraDuringRecording()
    }
    
    private var videoRecordingSyncTask: Task<Void, Never>?
    
    private func setupVideoRecorderBinding() {
        videoRecordingSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                // Проверяем, что задача не отменена перед каждым обновлением
                guard !Task.isCancelled else { break }
                
                if self.videoRecorder.isRecording {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.isRecordingVideo = true
                        self.videoRecordingDuration = self.videoRecorder.recordingDuration
                    }
                } else if self.isRecordingVideo {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        self.isRecordingVideo = false
                        self.videoRecordingDuration = 0
                    }
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
        }
    }

    // MARK: - Computed Properties

    var displayName: String {
        return chat?.displayName ?? "Чате"
    }

    var displayAvatarUrl: String? {
        return chat?.displayAvatarUrl
    }

    var isPrivateChat: Bool {
        return chat?.type == .private
    }

    var otherMembers: [ChatMember] {
        guard let chat = chat, let members = chat.members else { return [] }
        let userId = currentUserId
        guard let userId = userId else { return members }
        return members.filter { $0.userId != userId }
    }

    var currentUserId: String? {
        return TRPCService.shared.currentUser?.id
    }
    
    // MARK: - Reply Operations
    
    func setReplyingToMessage(_ message: ChatMessage?) {
        replyingToMessage = message
    }
    
    func clearReplyingToMessage() {
        replyingToMessage = nil
    }
    
    func findMessage(by id: String) -> ChatMessage? {
        return messages.first { $0.id == id }
    }
    
    // MARK: - Reaction Operations
    
    func handleReaction(messageId: String, emoji: String) {
        Task {
            do {
                // Проверяем, есть ли уже такая реакция от текущего пользователя
                guard let message = messages.first(where: { $0.id == messageId }),
                      let currentUserId = TRPCService.shared.currentUser?.id else {
                    return
                }
                
                let hasReaction = message.reactions?.contains { reaction in
                    reaction.userId == currentUserId && reaction.emoji == emoji
                } ?? false
                
                if hasReaction {
                    // Удаляем реакцию
                    try await chatService.removeReaction(messageId: messageId, emoji: emoji)
                } else {
                    // Добавляем реакцию
                    _ = try await chatService.addReaction(messageId: messageId, emoji: emoji)
                }
                
                // Обновляем сообщение локально
                await refreshMessage(messageId: messageId)
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to handle reaction: \(error)")
            }
        }
    }
    
    private func refreshMessage(messageId: String) {
        // Перезагружаем сообщения для получения обновленных реакций
        // В реальном приложении лучше обновить только конкретное сообщение
        loadMessages()
    }
}

