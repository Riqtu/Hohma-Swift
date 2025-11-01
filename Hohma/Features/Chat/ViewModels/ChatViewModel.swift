//
//  ChatViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

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

    private let chatService = ChatService.shared
    private var chatSocketManager: ChatSocketManager?
    private var socketAdapter: SocketIOServiceAdapter?
    private var chatId: String?
    private var typingTimer: Timer?
    private var lastTypingTime: Date?
    private let messagesPageSize = 30  // Размер страницы при загрузке

    init() {
        setupSocketAdapter()
    }

    deinit {
        typingTimer?.invalidate()
        // leaveChat() не вызываем в deinit, так как это main actor метод
        // Вместо этого используем Task для безопасного вызова
        if let chatId = chatId, let manager = chatSocketManager {
            Task { @MainActor in
                manager.leaveChat(chatId: chatId)
            }
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
                // Добавляем сообщение только если его еще нет
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    self.messages.sort { $0.createdAt < $1.createdAt }
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
                self.chat = loadedChat
                loadMessages()

                // Присоединяемся к комнате чата через Socket.IO
                joinChat()
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to load chat: \(error)")
            }

            isLoading = false
        }
    }

    func loadMessages() {
        guard let chatId = chatId else { return }

        Task {
            isLoadingMessages = true
            hasMoreMessages = true  // Сбрасываем флаг при новой загрузке

            do {
                let loadedMessages = try await chatService.getMessages(
                    chatId: chatId,
                    limit: messagesPageSize,
                    before: nil
                )
                self.messages = loadedMessages.sorted { $0.createdAt < $1.createdAt }
                
                // Если загрузили меньше чем запросили, значит больше нет сообщений
                if loadedMessages.count < messagesPageSize {
                    hasMoreMessages = false
                }

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
              let firstMessage = messages.first
        else { return }

        Task {
            isLoadingMoreMessages = true

            do {
                let loadedMessages = try await chatService.getMessages(
                    chatId: chatId,
                    limit: messagesPageSize,
                    before: firstMessage.id
                )
                
                // Если загрузили меньше чем запросили, значит больше нет сообщений
                if loadedMessages.count < messagesPageSize {
                    hasMoreMessages = false
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
        
        // Очищаем input перед отправкой
        messageInput = ""
        selectedAttachments = []

        Task {
            isSending = true
            isUploadingAttachments = !attachmentsToUpload.isEmpty
            errorMessage = nil

            do {
                // Загружаем вложения, если есть
                var attachmentURLs: [String] = []
                if !attachmentsToUpload.isEmpty {
                    attachmentURLs = try await uploadAttachments(attachmentsToUpload)
                }

                // Определяем тип сообщения
                let messageType: MessageType
                if !attachmentURLs.isEmpty {
                    // Проверяем, все ли вложения - изображения
                    let allImages = attachmentsToUpload.allSatisfy { $0.isImage }
                    messageType = allImages ? .image : .file
                } else {
                    messageType = .text
                }

                let request = SendMessageRequest(
                    chatId: chatId,
                    content: content.isEmpty ? (messageType == .image ? "Фото" : "Файл") : content,
                    messageType: messageType,
                    attachments: attachmentURLs.isEmpty ? nil : attachmentURLs,
                    replyToId: nil
                )

                let sentMessage = try await chatService.sendMessage(request)
                
                // Добавляем сообщение в список
                if !messages.contains(where: { $0.id == sentMessage.id }) {
                    messages.append(sentMessage)
                    messages.sort { $0.createdAt < $1.createdAt }
                }

                // Останавливаем индикатор печати
                stopTyping()
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatViewModel: Failed to send message: \(error)")
                // Восстанавливаем текст сообщения при ошибке
                messageInput = content
                selectedAttachments = attachmentsToUpload
            }

            isSending = false
            isUploadingAttachments = false
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
            } else if let fileData = attachment.fileData {
                // Загружаем файл
                let fileName = attachment.fileName ?? "file_\(UUID().uuidString)"
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
}

