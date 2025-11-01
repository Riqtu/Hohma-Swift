//
//  ChatListView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Inject
import SwiftUI
import Foundation

struct ChatListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = ChatListViewModel()
    @State private var selectedChat: Chat?
    @State private var chatToDelete: Chat? = nil

    var body: some View {
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
        .sheet(isPresented: $viewModel.showingCreateChat) {
            NavigationStack {
                CreateChatView()
            }
            .onDisappear {
                viewModel.refreshChats()
            }
        }
        .sheet(item: $selectedChat) { chat in
            NavigationStack {
                ChatView(chatId: chat.id)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) { notification in
            // Обрабатываем навигацию к конкретному чату
            if let destination = notification.userInfo?["destination"] as? String,
               destination == "chat",
               let chatId = notification.userInfo?["chatId"] as? String
            {
                print("💬 ChatListView: Navigation requested to chat \(chatId)")
                
                // Ищем чат в загруженных чатах
                if let chat = viewModel.chats.first(where: { $0.id == chatId }) {
                    selectedChat = chat
                } else {
                    // Если чат не найден, загружаем его по ID
                    Task {
                        await loadChatById(chatId: chatId)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadChats()
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
                selectedChat = chat
            }
        } catch {
            print("❌ ChatListView: Failed to load chat by ID: \(error)")
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
            ForEach(viewModel.chats) { chat in
                ChatCellView(chat: chat)
                    .contentShape(Rectangle())
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            chatToDelete = chat
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        selectedChat = chat
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable {
            viewModel.refreshChats()
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
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chat Cell View
struct ChatCellView: View {
    @ObserveInjection var inject
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: chat.displayAvatarUrl ?? "")) { image in
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
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let lastMessage = chat.messages?.last {
                    HStack {
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        if chat.unreadCountValue > 0 {
                            Text("\(chat.unreadCountValue)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color("AccentColor"))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
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
