//
//  CreateChatView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import SwiftUI
import Inject

struct CreateChatView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreateChatViewModel()
    @State private var chatName: String = ""
    @State private var chatDescription: String = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var chatType: ChatType = .private
    @State private var searchQuery: String = ""

    var body: some View {
        Form {
            // Chat type
            Section("Тип чата") {
                Picker("Тип чата", selection: $chatType) {
                    Text("Личный").tag(ChatType.private)
                    Text("Групповой").tag(ChatType.group)
                }
            }

            // Group chat name
            if chatType == .group {
                Section("Название чата") {
                    TextField("Название", text: $chatName)
                    TextField("Описание (необязательно)", text: $chatDescription)
                }
            }

            // User selection
            Section("Выбрать пользователей") {
                TextField("Поиск пользователей...", text: $searchQuery)
                    .onChange(of: searchQuery) { _, newValue in
                        if newValue.count >= 2 {
                            viewModel.searchUsers(query: newValue)
                        }
                    }

                if viewModel.isSearching {
                    ProgressView()
                } else {
                    ForEach(viewModel.searchResults) { user in
                        UserSelectionRow(
                            user: user,
                            isSelected: selectedUserIds.contains(user.id)
                        ) {
                            if selectedUserIds.contains(user.id) {
                                selectedUserIds.remove(user.id)
                            } else {
                                selectedUserIds.insert(user.id)
                            }
                        }
                    }
                }
            }

            // Selected users
            if !selectedUserIds.isEmpty {
                Section("Выбрано пользователей: \(selectedUserIds.count)") {
                    ForEach(viewModel.searchResults.filter { selectedUserIds.contains($0.id) }) { user in
                        HStack {
                            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())

                            Text(user.displayName)

                            Spacer()

                            Button(action: {
                                selectedUserIds.remove(user.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Создать чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Создать") {
                    createChat()
                }
                .disabled(!canCreateChat || viewModel.isCreating)
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var canCreateChat: Bool {
        if chatType == .private {
            return selectedUserIds.count == 1
        } else {
            return !chatName.isEmpty && !selectedUserIds.isEmpty
        }
    }

    private func createChat() {
        Task {
            await viewModel.createChat(
                type: chatType,
                userIds: Array(selectedUserIds),
                name: chatType == .group ? (chatName.isEmpty ? nil : chatName) : nil,
                description: chatType == .group ? (chatDescription.isEmpty ? nil : chatDescription) : nil,
                avatarUrl: nil
            )
            
            if viewModel.createdChat != nil {
                dismiss()
            }
        }
    }
}

// MARK: - User Selection Row
struct UserSelectionRow: View {
    @ObserveInjection var inject
    let user: UserProfile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .foregroundColor(.primary)
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}


