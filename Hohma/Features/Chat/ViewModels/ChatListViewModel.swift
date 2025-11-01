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
                self.chats = loadedChats
            } catch {
                errorMessage = error.localizedDescription
                print("❌ ChatListViewModel: Failed to load chats: \(error)")
            }

            isLoading = false
        }
    }

    func refreshChats() {
        loadChats()
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


