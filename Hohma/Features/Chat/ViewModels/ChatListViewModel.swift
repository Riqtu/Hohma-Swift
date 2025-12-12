//
//  ChatListViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = [] {
        didSet {
            // Обновляем totalUnreadCount при изменении chats для обновления badge
            let newCount = chats.reduce(0) { $0 + $1.unreadCountValue }
            if totalUnreadCount != newCount {
                totalUnreadCount = newCount
                AppLogger.shared.debug("totalUnreadCount updated to \(totalUnreadCount)", category: .general)
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    @Published var showingCreateChat: Bool = false
    @Published var totalUnreadCount: Int = 0 {  // Published для обновления badge в TabView
        didSet {
            // Обновляем badge на иконке приложения при изменении счетчика
            updateApplicationIconBadge()
        }
    }

    private let chatService = ChatService.shared
    private var socketAdapter: SocketIOServiceAdapter?
    private var chatSocketManager: ChatSocketManager?
    private var notificationObserver: NSObjectProtocol?
    
    private func updateApplicationIconBadge() {
        #if os(iOS)
        PushNotificationService.shared.updateApplicationIconBadge(totalUnreadCount)
        #endif
    }

    init(autoLoad: Bool = true) {
        if autoLoad {
            loadChats()
        }
        setupGlobalSocketListener()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Подписываемся на уведомления об обновлении списка чатов
        // Это позволяет обновлять badge даже когда пользователь не на экране чатов
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .chatListUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let chatId = notification.userInfo?["chatId"] as? String ?? "unknown"
            AppLogger.shared.debug("Received .chatListUpdated notification for chat \(chatId), refreshing chats", category: .general)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                AppLogger.shared.debug("Starting refreshChatsAsync from notification", category: .general)
                await self.refreshChatsAsync()
                AppLogger.shared.debug("refreshChatsAsync completed from notification, totalUnreadCount: \(self.totalUnreadCount)", category: .general)
            }
        }
    }
    
    deinit {
        // Очищаем ресурсы при деинициализации
        socketAdapter?.disconnect()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupGlobalSocketListener() {
        guard let authToken = TRPCService.shared.authToken else {
            AppLogger.shared.error("No auth token available for socket", category: .auth)
            return
        }
        
        // Создаем отдельный socket adapter для глобального слушателя
        socketAdapter = SocketIOServiceAdapter(authToken: authToken)
        
        guard let adapter = socketAdapter else {
            AppLogger.shared.error("Failed to create SocketAdapter", category: .general)
            return
        }
        
        chatSocketManager = ChatSocketManager(socket: adapter)
        setupSocketCallbacks()
        
        // Подключаемся к сокету
        // Обработчик connect автоматически присоединит к глобальной комнате пользователя
        adapter.connect()
        
        // Если сокет уже подключен, сразу присоединяемся к комнате
        if adapter.isConnected {
            joinUserGlobalRoom()
        }
    }
    
    private func setupSocketCallbacks() {
        guard let manager = chatSocketManager,
              let adapter = socketAdapter else {
            AppLogger.shared.error("Cannot setup socket callbacks - missing manager or adapter", category: .general)
            return
        }
        
        AppLogger.shared.debug("Setting up socket callbacks", category: .general)
        
        // Слушаем подключение socket и присоединяемся к глобальной комнате пользователя
        adapter.on(.connect) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.shared.debug("===== Socket connected =====", category: .general)
            AppLogger.shared.debug("Socket connected, joining user global room", category: .general)
            Task { @MainActor in
                // Небольшая задержка, чтобы убедиться, что сокет полностью готов
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
                self.joinUserGlobalRoom()
            }
        }
        
        // Слушаем обновления списка чатов из глобальной комнаты пользователя
        AppLogger.shared.debug("Registering onChatListUpdated callback", category: .general)
        manager.onChatListUpdated = { [weak self] chatId in
            guard let self = self else { return }
            AppLogger.shared.debug("===== CHAT LIST UPDATED EVENT ======", category: .general)
            AppLogger.shared.debug("Chat ID: \(chatId)", category: .general)
            AppLogger.shared.debug("Current chats count: \(self.chats.count)", category: .general)
            AppLogger.shared.debug("Current totalUnreadCount: \(self.totalUnreadCount)", category: .general)
            AppLogger.shared.debug("Refreshing immediately...", category: .general)
            
            // Обновляем список чатов напрямую для обновления badge
            // Используем async без await, чтобы не блокировать
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                AppLogger.shared.debug("Starting refreshChatsAsync from WebSocket callback", category: .general)
                await self.refreshChatsAsync()
                AppLogger.shared.debug("refreshChatsAsync completed", category: .general)
                AppLogger.shared.debug("New chats count: \(self.chats.count)", category: .general)
                AppLogger.shared.debug("New totalUnreadCount: \(self.totalUnreadCount)", category: .general)
                AppLogger.shared.debug("===== REFRESH COMPLETE =====", category: .general)
            }
            
            // Также отправляем уведомление для других подписчиков (например, ChatListView)
            NotificationCenter.default.post(
                name: .chatListUpdated,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
        
        AppLogger.shared.debug("Socket callbacks setup completed", category: .general)
    }
    
    private func joinUserGlobalRoom() {
        guard let manager = chatSocketManager,
              let userId = TRPCService.shared.currentUser?.id,
              let adapter = socketAdapter else {
            AppLogger.shared.error("Cannot join user room - missing manager, userId, or adapter", category: .general)
            return
        }
        
        // Проверяем, подключен ли socket
        guard adapter.isConnected else {
            AppLogger.shared.warning("Socket not connected yet, will join user room when connected", category: .general)
            // Попробуем подключиться, если еще не подключены
            adapter.connect()
            // Обработчик connect автоматически вызовет joinUserGlobalRoom() при подключении
            return
        }
        
        // Присоединяемся к глобальной комнате пользователя для получения уведомлений о чатах
        AppLogger.shared.debug("Joining user global room for user \(userId)", category: .general)
        manager.joinUser(userId: userId)
        AppLogger.shared.debug("Joined user global room for user \(userId)", category: .general)
    }

    func loadChats() {
        // Предотвращаем множественные одновременные загрузки
        guard !isLoading else {
            AppLogger.shared.debug("loadChats() already in progress, skipping", category: .general)
            return
        }
        
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                let loadedChats = try await chatService.getChats(
                    limit: 50,
                    offset: 0,
                    search: searchQuery.isEmpty ? nil : searchQuery
                )
                AppLogger.shared.debug("Loaded \(loadedChats.count) chats", category: .general)
                for chat in loadedChats {
                    AppLogger.shared.debug("Chat \(chat.id) - unreadCount: \(chat.unreadCountValue)", category: .general)
                }
                self.chats = loadedChats
                // Присоединяемся к глобальной комнате пользователя после загрузки
                self.joinUserGlobalRoom()
                // Обновляем badge на иконке приложения после загрузки
                self.updateApplicationIconBadge()
                isLoading = false
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                AppLogger.shared.error("Failed to load chats", error: error, category: .general)
                isLoading = false
            }
        }
    }

    func refreshChats() {
        // При обновлении не показываем loading индикатор, чтобы не блокировать UI
        AppLogger.shared.debug("refreshChats() called", category: .general)
        Task {
            await refreshChatsAsync()
        }
    }
    
    func refreshChatsAsync() async {
        errorMessage = nil

        do {
            let loadedChats = try await chatService.getChats(
                limit: 50,
                offset: 0,
                search: searchQuery.isEmpty ? nil : searchQuery
            )
            AppLogger.shared.debug("Refreshed \(loadedChats.count) chats", category: .general)
            AppLogger.shared.debug("Previous chats count: \(self.chats.count)", category: .general)
            
            for chat in loadedChats {
                AppLogger.shared.debug("Chat \(chat.id) - unreadCount: \(chat.unreadCountValue), name: \(chat.displayName), lastMessageAt: \(chat.lastMessageAt ?? "nil")", category: .general)
            }
            
            // Принудительно обновляем список
            await MainActor.run {
                let oldUnreadCount = self.totalUnreadCount
                let oldChatsCount = self.chats.count
                
                // Принудительно обновляем UI перед изменением данных
                self.objectWillChange.send()
                
                // Всегда обновляем, чтобы гарантировать обновление UI
                // SwiftUI может не увидеть изменения в свойствах объектов, поэтому создаем новый массив
                self.chats = loadedChats
                
                let newUnreadCount = self.totalUnreadCount
                AppLogger.shared.debug("Updated chats array", category: .general)
                AppLogger.shared.debug("   - Count: \(oldChatsCount) -> \(self.chats.count)", category: .general)
                AppLogger.shared.debug("   - Unread count: \(oldUnreadCount) -> \(newUnreadCount)", category: .general)
                
                // Обновляем badge на иконке приложения
                self.updateApplicationIconBadge()
                
                // Принудительно обновляем UI после изменения данных
                self.objectWillChange.send()
                
                // Дополнительно обновляем через DispatchQueue для гарантии
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.shared.error("Failed to refresh chats", error: error, category: .general)
        }
    }

    func searchChats(query: String) {
        searchQuery = query
        loadChats()
    }

    func deleteChat(chatId: String) {
        Task {
            do {
                try await chatService.leaveChat(chatId: chatId)
                chats.removeAll { $0.id == chatId }
            } catch {
                errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
            }
        }
    }
}


