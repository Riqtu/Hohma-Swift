//
//  CreateChatViewModel.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Foundation

@MainActor
final class CreateChatViewModel: ObservableObject {
    @Published var searchResults: [UserProfile] = []
    @Published var isSearching: Bool = false
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var createdChat: Chat?

    private let chatService = ChatService.shared
    private let profileService = ProfileService.shared

    func searchUsers(query: String) {
        Task {
            isSearching = true
            errorMessage = nil

            do {
                let results = try await profileService.searchUsers(query: query, limit: 20)
                self.searchResults = results
            } catch {
                errorMessage = error.localizedDescription
                print("❌ CreateChatViewModel: Failed to search users: \(error)")
            }

            isSearching = false
        }
    }

    func createChat(
        type: ChatType,
        userIds: [String],
        name: String?,
        description: String?,
        avatarUrl: String?
    ) async {
        isCreating = true
        errorMessage = nil

        do {
            let request = CreateChatRequest(
                type: type,
                userIds: userIds,
                name: name,
                description: description,
                avatarUrl: avatarUrl
            )

            let chat = try await chatService.createChat(request)
            self.createdChat = chat
        } catch {
            errorMessage = error.localizedDescription
            print("❌ CreateChatViewModel: Failed to create chat: \(error)")
        }

        isCreating = false
    }
}


