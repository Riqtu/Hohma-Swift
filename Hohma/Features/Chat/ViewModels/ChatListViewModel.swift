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
                print("💬 ChatListViewModel: totalUnreadCount updated to \(totalUnreadCount)")
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
            print("💬 ChatListViewModel: Received .chatListUpdated notification for chat \(chatId), refreshing chats")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("💬 ChatListViewModel: Starting refreshChatsAsync from notification")
                await self.refreshChatsAsync()
                print("💬 ChatListViewModel: refreshChatsAsync completed from notification, totalUnreadCount: \(self.totalUnreadCount)")
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
            print("❌ ChatListViewModel: No auth token available for socket")
            return
        }
        
        // Создаем отдельный socket adapter для глобального слушателя
        socketAdapter = SocketIOServiceAdapter(authToken: authToken)
        
        guard let adapter = socketAdapter else {
            print("❌ ChatListViewModel: Failed to create SocketAdapter")
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
            print("❌ ChatListViewModel: Cannot setup socket callbacks - missing manager or adapter")
            return
        }
        
        print("💬 ChatListViewModel: Setting up socket callbacks")
        
        // Слушаем подключение socket и присоединяемся к глобальной комнате пользователя
        adapter.on(.connect) { [weak self] _ in
            guard let self = self else { return }
            print("💬 ChatListViewModel: ===== Socket connected =====")
            print("💬 ChatListViewModel: Socket connected, joining user global room")
            Task { @MainActor in
                // Небольшая задержка, чтобы убедиться, что сокет полностью готов
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
                self.joinUserGlobalRoom()
            }
        }
        
        // Слушаем обновления списка чатов из глобальной комнаты пользователя
        print("💬 ChatListViewModel: Registering onChatListUpdated callback")
        manager.onChatListUpdated = { [weak self] chatId in
            guard let self = self else { return }
            print("💬 ChatListViewModel: ===== CHAT LIST UPDATED EVENT ======")
            print("💬 ChatListViewModel: Chat ID: \(chatId)")
            print("💬 ChatListViewModel: Current chats count: \(self.chats.count)")
            print("💬 ChatListViewModel: Current totalUnreadCount: \(self.totalUnreadCount)")
            print("💬 ChatListViewModel: Refreshing immediately...")
            
            // Обновляем список чатов напрямую для обновления badge
            // Используем async без await, чтобы не блокировать
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("💬 ChatListViewModel: Starting refreshChatsAsync from WebSocket callback")
                await self.refreshChatsAsync()
                print("💬 ChatListViewModel: refreshChatsAsync completed")
                print("💬 ChatListViewModel: New chats count: \(self.chats.count)")
                print("💬 ChatListViewModel: New totalUnreadCount: \(self.totalUnreadCount)")
                print("💬 ChatListViewModel: ===== REFRESH COMPLETE ======")
            }
            
            // Также отправляем уведомление для других подписчиков (например, ChatListView)
            NotificationCenter.default.post(
                name: .chatListUpdated,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
        
        print("💬 ChatListViewModel: Socket callbacks setup completed")
    }
    
    private func joinUserGlobalRoom() {
        guard let manager = chatSocketManager,
              let userId = TRPCService.shared.currentUser?.id,
              let adapter = socketAdapter else {
            print("❌ ChatListViewModel: Cannot join user room - missing manager, userId, or adapter")
            return
        }
        
        // Проверяем, подключен ли socket
        guard adapter.isConnected else {
            print("⚠️ ChatListViewModel: Socket not connected yet, will join user room when connected")
            // Попробуем подключиться, если еще не подключены
            adapter.connect()
            // Обработчик connect автоматически вызовет joinUserGlobalRoom() при подключении
            return
        }
        
        // Присоединяемся к глобальной комнате пользователя для получения уведомлений о чатах
        print("💬 ChatListViewModel: Joining user global room for user \(userId)")
        manager.joinUser(userId: userId)
        print("💬 ChatListViewModel: Joined user global room for user \(userId)")
    }

    func loadChats() {
        // Предотвращаем множественные одновременные загрузки
        guard !isLoading else {
            print("💬 ChatListViewModel: loadChats() already in progress, skipping")
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
                print("💬 ChatListViewModel: Loaded \(loadedChats.count) chats")
                for chat in loadedChats {
                    print("💬 ChatListViewModel: Chat \(chat.id) - unreadCount: \(chat.unreadCountValue)")
                }
                self.chats = loadedChats
                // Присоединяемся к глобальной комнате пользователя после загрузки
                self.joinUserGlobalRoom()
                // Обновляем badge на иконке приложения после загрузки
                self.updateApplicationIconBadge()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatListViewModel: Failed to load chats: \(error)")
                isLoading = false
            }
        }
    }

    func refreshChats() {
        // При обновлении не показываем loading индикатор, чтобы не блокировать UI
        print("🔄 ChatListViewModel: refreshChats() called")
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
            print("💬 ChatListViewModel: Refreshed \(loadedChats.count) chats")
            print("💬 ChatListViewModel: Previous chats count: \(self.chats.count)")
            
            for chat in loadedChats {
                print("💬 ChatListViewModel: Chat \(chat.id) - unreadCount: \(chat.unreadCountValue), name: \(chat.displayName), lastMessageAt: \(chat.lastMessageAt ?? "nil")")
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
                print("💬 ChatListViewModel: Updated chats array")
                print("💬 ChatListViewModel:   - Count: \(oldChatsCount) -> \(self.chats.count)")
                print("💬 ChatListViewModel:   - Unread count: \(oldUnreadCount) -> \(newUnreadCount)")
                
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
            print("❌ ChatListViewModel: Failed to refresh chats: \(error)")
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
                errorMessage = error.localizedDescription
            }
        }
    }
}


