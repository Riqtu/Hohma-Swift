//
//  ChatListView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation
import Inject
import SwiftUI

struct ChatListView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: ChatListViewModel
    @State private var chatToDelete: Chat? = nil
    @State private var navigationPath = NavigationPath()

    // Инициализатор для использования с shared viewModel или создания нового
    init(viewModel: ChatListViewModel? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel ?? ChatListViewModel())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                searchBarView

                // Chat list
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    loadingView
                } else if viewModel.chats.isEmpty {
                    emptyStateView
                } else {
                    chatListView
                }
            }
            .background(Color.clear)
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showingCreateChat = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Chat.self) { chat in
                ChatView(chatId: chat.id)
                    .onDisappear {
                        // Обновляем список чатов при возврате из чата
                        // чтобы обновить счетчик непрочитанных сообщений
                        AppLogger.shared.debug("ChatView disappeared, refreshing chat list", category: .ui)
                        // Используем небольшую задержку, чтобы убедиться, что навигация завершена
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 секунды
                            await viewModel.refreshChatsAsync()
                        }
                    }
            }
        }
        .sheet(isPresented: $viewModel.showingCreateChat) {
            NavigationStack {
                CreateChatView()
            }
            .onDisappear {
                viewModel.refreshChats()
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Удалить чат?", isPresented: .constant(chatToDelete != nil)) {
            Button("Отмена", role: .cancel) {
                chatToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                if let chat = chatToDelete {
                    viewModel.deleteChat(chatId: chat.id)
                    chatToDelete = nil
                }
            }
        } message: {
            Text("Вы уверены, что хотите удалить этот чат? Все сообщения будут удалены.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Обрабатываем навигацию к конкретному чату
            if let destination = notification.userInfo?["destination"] as? String,
                destination == "chat",
                let chatId = notification.userInfo?["chatId"] as? String
            {
                AppLogger.shared.debug("Navigation requested to chat \(chatId)", category: .ui)

                // Ищем чат в загруженных чатах
                if let chat = viewModel.chats.first(where: { $0.id == chatId }) {
                    navigationPath.append(chat)
                } else {
                    // Если чат не найден, загружаем его по ID
                    Task {
                        await loadChatById(chatId: chatId)
                    }
                }
            }
        }
        .onAppear {
            AppLogger.shared.debug("onAppear - loading chats", category: .ui)
            viewModel.loadChats()
        }
        .onChange(of: navigationPath.count) { oldValue, newValue in
            // Обновляем список чатов при изменении навигации (возврат из чата)
            if newValue < oldValue {
                AppLogger.shared.debug("Navigation path changed (returned from chat), refreshing", category: .ui)
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 секунды для завершения анимации
                    await viewModel.refreshChatsAsync()
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in
            // Обновляем список чатов при возврате приложения в foreground
            viewModel.refreshChats()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatListUpdated)) { notification in
            // Обновляем список чатов при получении уведомления об обновлении
            // Это происходит при отметке сообщений как прочитанных или при получении новых сообщений
            let chatId = notification.userInfo?["chatId"] as? String ?? "unknown"
            AppLogger.shared.debug("Received .chatListUpdated notification for chat \(chatId)", category: .ui)
            AppLogger.shared.debug("Current chats count: \(viewModel.chats.count)", category: .ui)
            AppLogger.shared.debug("Calling refreshChats()...", category: .ui)
            viewModel.refreshChats()
        }
    }

    // MARK: - Helper Methods
    private func loadChatById(chatId: String) async {
        do {
            let chat = try await ChatService.shared.getChatById(chatId: chatId)
            await MainActor.run {
                // Добавляем чат в список, если его там нет
                if !viewModel.chats.contains(where: { $0.id == chatId }) {
                    viewModel.chats.insert(chat, at: 0)
                }
                navigationPath.append(chat)
            }
        } catch {
            AppLogger.shared.error("Failed to load chat by ID: \(error)", category: .ui)
        }
    }

    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Поиск чатов...", text: $viewModel.searchQuery)
                .onChange(of: viewModel.searchQuery) { _, newValue in
                    if newValue.isEmpty {
                        viewModel.loadChats()
                    } else {
                        viewModel.searchChats(query: newValue)
                    }
                }
            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                    viewModel.loadChats()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Chat List
    private var chatListView: some View {
        List {
            ForEach(viewModel.chats, id: \.id) { chat in
                NavigationLink(value: chat) {
                    ChatCellView(chat: chat)
                        .id(
                            "chat-\(chat.id)-\(chat.unreadCountValue)-\(chat.lastMessageAt ?? "")-\(chat.updatedAt)"
                        )  // Принудительное обновление при изменении
                }
                .contentShape(Rectangle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 20))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        chatToDelete = chat
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color("AccentColor"))
                            .clipShape(Circle())
                    }
                    .tint(Color("AccentColor"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .listStyle(.plain)
        .refreshable {
            AppLogger.shared.debug("Pull-to-refresh triggered", category: .ui)
            await viewModel.refreshChatsAsync()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка чатов...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Чатов пока нет")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Создайте новый чат для начала общения")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Создать чат") {
                viewModel.showingCreateChat = true
            }
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color("AccentColor"))
            .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat Cell View
struct ChatCellView: View {
    @ObserveInjection var inject
    let chat: Chat

    // Debug: выводим счетчик для отладки
    private var unreadCount: Int {
        let count = chat.unreadCountValue
        if count > 0 {
            AppLogger.shared.debug("Chat \(chat.id) has \(count) unread messages", category: .ui)
        }
        return count
    }

    // Computed property для URL аватарки с timestamp для принудительного обновления
    private var avatarURL: URL? {
        guard let avatarUrl = chat.displayAvatarUrl, !avatarUrl.isEmpty else {
            return nil
        }
        // Добавляем timestamp для принудительного обновления кеша
        let urlWithTimestamp =
            avatarUrl.contains("?")
            ? "\(avatarUrl)&t=\(chat.updatedAt.hashValue)"
            : "\(avatarUrl)?t=\(chat.updatedAt.hashValue)"
        return URL(string: urlWithTimestamp)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Group {
                if let url = avatarURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(
                            systemName: chat.type == .private
                                ? "person.circle.fill" : "person.2.circle.fill"
                        )
                        .resizable()
                        .foregroundColor(.secondary)
                    }
                } else {
                    Image(
                        systemName: chat.type == .private
                            ? "person.circle.fill" : "person.2.circle.fill"
                    )
                    .resizable()
                    .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .id("avatar-\(chat.id)-\(chat.displayAvatarUrl ?? "")-\(chat.updatedAt)")  // Уникальный ID для принудительного обновления

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(chat.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(unreadCount > 0 ? .semibold : .regular)

                    Spacer()

                    HStack(alignment: .center, spacing: 6) {
                        if let lastMessageAt = chat.lastMessageAt {
                            Text(formatDate(lastMessageAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Счетчик непрочитанных рядом с датой
                        if unreadCount > 0 {
                            Text("\(unreadCount > 99 ? "99+" : "\(unreadCount)")")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 20)
                                .padding(.horizontal, unreadCount > 99 ? 5 : 6)
                                .padding(.vertical, 3)
                                .background(Color("AccentColor"))
                                .clipShape(Capsule())
                        }
                    }
                }

                if let lastMessage = chat.messages?.last {
                    HStack(spacing: 4) {
                        let (icon, text) = getLastMessagePreview(for: lastMessage)
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundColor(unreadCount > 0 ? .primary : .secondary)
                        }
                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(unreadCount > 0 ? .primary : .secondary)
                            .lineLimit(1)
                    }
                } else if unreadCount > 0 {
                    // Показываем индикатор непрочитанных, даже если нет последнего сообщения
                    Text("Непрочитанные сообщения")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 8)
    }

    private func getLastMessagePreview(for message: ChatMessage) -> (icon: String?, text: String) {
        switch message.messageType {
        case .sticker:
            return ("face.smiling", "Стикер")
        case .image:
            return ("photo", "Фото")
        case .file:
            return ("doc", "Файл")
        case .system:
            return (nil, message.content)
        case .text:
            return (nil, message.content)
        case .movieBattle:
            return ("film.fill", message.battle?.name ?? "Батл фильмов")
        case .race:
            return ("flag.checkered", message.race?.name ?? "Скачка")
        case .wheel:
            return ("circle.dotted", message.wheel?.name ?? "Колесо")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                formatter.dateFormat = "HH:mm"
                return formatter.string(from: date)
            } else if calendar.isDateInYesterday(date) {
                return "Вчера"
            } else {
                formatter.dateFormat = "dd.MM"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

#Preview {
    ChatListView()
}
