//
//  ChatListViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    @Published var showingCreateChat: Bool = false

    private let chatService = ChatService.shared

    init() {
        loadChats()
    }

    func loadChats() {
        Task {
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
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatListViewModel: Failed to load chats: \(error)")
            }

            isLoading = false
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
                print("💬 ChatListViewModel: Chat \(chat.id) - unreadCount: \(chat.unreadCountValue), name: \(chat.displayName)")
            }
            
            // Принудительно обновляем список
            await MainActor.run {
                // Всегда обновляем, чтобы гарантировать обновление UI
                // SwiftUI может не увидеть изменения в свойствах объектов, поэтому создаем новый массив
                self.chats = loadedChats
                print("💬 ChatListViewModel: Updated chats array, new count: \(self.chats.count)")
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


