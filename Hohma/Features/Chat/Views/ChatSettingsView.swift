//
//  ChatSettingsView.swift
//  Hohma
//
//  Created by Assistant on 30.11.2025.
//

import Inject
import PhotosUI
import SwiftUI

struct ChatSettingsView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) var dismiss
    let chatId: String
    @StateObject private var viewModel: ChatSettingsViewModel
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedBackgroundItem: PhotosPickerItem?
    @State private var showNameEditor = false
    @State private var showDescriptionEditor = false
    @State private var editingName: String = ""
    @State private var editingDescription: String = ""
    @State private var searchDebouncer: Timer?

    init(chatId: String) {
        self.chatId = chatId
        self._viewModel = StateObject(wrappedValue: ChatSettingsViewModel(chatId: chatId))
    }

    var body: some View {
        NavigationView {
            Form {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    // Информация о чате
                    chatInfoSection

                    // Настройки уведомлений
                    notificationsSection

                    // Настройки группы (только для групповых чатов)
                    if viewModel.isGroupChat {
                        groupSettingsSection
                    }

                    // Участники (только для групповых чатов)
                    if viewModel.isGroupChat {
                        membersSection
                    }
                }
            }
            .navigationTitle("Настройки чата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadChat()
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showNameEditor) {
                nameEditorSheet
            }
            .sheet(isPresented: $showDescriptionEditor) {
                descriptionEditorSheet
            }
            .sheet(isPresented: $viewModel.showAddMemberSheet) {
                addMemberSheet
            }
        }
        .enableInjection()
    }

    // MARK: - Chat Info Section
    private var chatInfoSection: some View {
        Section {
            if let otherUserId = viewModel.otherUserId, !viewModel.isGroupChat {
                NavigationLink(
                    destination: OtherUserProfileView(
                        userId: otherUserId, useNavigationStack: false)
                ) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: viewModel.chat?.displayAvatarUrl ?? "")) {
                            image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(
                                systemName: viewModel.isGroupChat
                                    ? "person.2.circle.fill" : "person.circle.fill"
                            )
                            .resizable()
                            .foregroundColor(.secondary)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())

                        Text(viewModel.chat?.displayName ?? "Чате")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: viewModel.chat?.displayAvatarUrl ?? "")) {
                        image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(
                            systemName: viewModel.isGroupChat
                                ? "person.2.circle.fill" : "person.circle.fill"
                        )
                        .resizable()
                        .foregroundColor(.secondary)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())

                    Text(viewModel.chat?.displayName ?? "Чате")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        Section("Уведомления") {
            Toggle(
                "Уведомления",
                isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.updateNotifications(enabled: $0) }
                )
            )
            .disabled(viewModel.isUpdating)

            Toggle(
                "Отключить звук",
                isOn: Binding(
                    get: { viewModel.isMuted },
                    set: { viewModel.updateMuteStatus(muted: $0) }
                )
            )
            .disabled(viewModel.isUpdating)
        }
    }

    // MARK: - Group Settings Section
    private var groupSettingsSection: some View {
        Section("Настройки группы") {
            // Название чата
            HStack {
                Text("Название")
                Spacer()
                Text(viewModel.chatName.isEmpty ? "Не указано" : viewModel.chatName)
                    .foregroundColor(.secondary)
                if viewModel.canEditChat {
                    Button(action: {
                        editingName = viewModel.chatName
                        showNameEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.accentColor)
                    }
                }
            }

            // Описание чата
            HStack {
                Text("Описание")
                Spacer()
                Text(viewModel.chatDescription.isEmpty ? "Не указано" : viewModel.chatDescription)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                if viewModel.canEditChat {
                    Button(action: {
                        editingDescription = viewModel.chatDescription
                        showDescriptionEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.accentColor)
                    }
                }
            }

            // Аватарка группы
            if viewModel.canEditChat {
                let isUploadingAvatar = viewModel.isUploadingAvatar
                PhotosPicker(
                    selection: $selectedAvatarItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Text("Изменить аватарку")
                        Spacer()
                        if isUploadingAvatar {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .disabled(isUploadingAvatar)
                .onChange(of: selectedAvatarItem) { _, newItem in
                    guard let newItem = newItem else { return }
                    Task { @MainActor in
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                            let image = UIImage(data: data)
                        {
                            viewModel.updateChatAvatar(image: image)
                            selectedAvatarItem = nil
                        }
                    }
                }
            }

            // Фон чата
            let isUploadingBackground = viewModel.isUploadingBackground
            PhotosPicker(
                selection: $selectedBackgroundItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Text("Изменить фон")
                    Spacer()
                    if isUploadingBackground {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .disabled(isUploadingBackground)
            .onChange(of: selectedBackgroundItem) { _, newItem in
                guard let newItem = newItem else { return }
                Task { @MainActor in
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                        let image = UIImage(data: data)
                    {
                        viewModel.updateChatBackground(image: image)
                        selectedBackgroundItem = nil
                    }
                }
            }

            if viewModel.getChatBackgroundUrl() != nil {
                Button(action: {
                    viewModel.removeChatBackground()
                }) {
                    HStack {
                        Text("Удалить фон")
                        Spacer()
                        if viewModel.isUpdating {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .disabled(viewModel.isUpdating)
            }
        }
    }

    // MARK: - Members Section
    private var membersSection: some View {
        Section {
            // Кнопка добавления участника
            if viewModel.canModerate {
                Button(action: {
                    viewModel.showAddMemberSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.accentColor)
                        Text("Добавить участника")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
            }

            // Список участников
            ForEach(viewModel.members.filter { $0.leftAt == nil }) { member in
                MemberRowView(
                    member: member,
                    currentUserMember: viewModel.currentUserMember,
                    canModerate: viewModel.canModerate,
                    onRoleChange: { role in
                        viewModel.updateMemberRole(userId: member.userId, role: role)
                    },
                    onRemove: {
                        viewModel.removeMember(userId: member.userId)
                    }
                )
            }
        } header: {
            Text("Участники (\(viewModel.members.filter { $0.leftAt == nil }.count))")
        }
    }

    // MARK: - Add Member Sheet
    private var addMemberSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск пользователей...", text: $viewModel.searchQuery)
                        .onChange(of: viewModel.searchQuery) { _, newValue in
                            debouncedSearch(query: newValue)
                        }
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                            viewModel.clearSearch()
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
                .padding()

                // Результаты поиска
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if viewModel.searchQuery.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Введите имя или username для поиска")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Пользователи не найдены")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.searchResults) { user in
                            AddMemberRowView(user: user) {
                                viewModel.addMember(userId: user.id)
                                viewModel.showAddMemberSheet = false
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Добавить участника")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        viewModel.showAddMemberSheet = false
                        viewModel.clearSearch()
                    }
                }
            }
        }
    }

    private func debouncedSearch(query: String) {
        // Отменяем предыдущий таймер
        searchDebouncer?.invalidate()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Task { @MainActor in
                viewModel.clearSearch()
            }
            return
        }

        // Создаем новый таймер с задержкой 500ms
        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                viewModel.searchUsers(query: query)
            }
        }
    }

    // MARK: - Name Editor Sheet
    private var nameEditorSheet: some View {
        NavigationView {
            Form {
                Section("Название чата") {
                    TextField("Название", text: $editingName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Изменить название")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showNameEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        viewModel.updateChatName(editingName)
                        showNameEditor = false
                    }
                    .disabled(editingName.isEmpty || editingName == viewModel.chatName)
                }
            }
        }
    }

    // MARK: - Description Editor Sheet
    private var descriptionEditorSheet: some View {
        NavigationView {
            Form {
                Section("Описание чата") {
                    TextField("Описание", text: $editingDescription, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle("Изменить описание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showDescriptionEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        viewModel.updateChatDescription(editingDescription)
                        showDescriptionEditor = false
                    }
                }
            }
        }
    }
}

// MARK: - Member Row View
struct MemberRowView: View {
    let member: ChatMember
    let currentUserMember: ChatMember?
    let canModerate: Bool
    let onRoleChange: (ChatRole) -> Void
    let onRemove: () -> Void

    @State private var showRolePicker = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Аватар
            NavigationLink(
                destination: OtherUserProfileView(userId: member.userId, useNavigationStack: false)
            ) {
                AsyncImage(url: URL(string: member.user?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()

            // Имя и роль
            VStack(alignment: .leading, spacing: 4) {
                Text(member.user?.displayName ?? "Пользователь")
                    .font(.body)

                HStack(spacing: 4) {
                    Text(roleDisplayName(member.role))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if member.userId == currentUserMember?.userId {
                        Text("(Вы)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Действия
            if canModerate && member.userId != currentUserMember?.userId {
                Menu {
                    // Изменить роль
                    if member.role != .owner {
                        Menu("Изменить роль") {
                            if member.role != .member {
                                Button("Участник") {
                                    onRoleChange(.member)
                                }
                            }
                            if member.role != .admin {
                                Button("Администратор") {
                                    onRoleChange(.admin)
                                }
                            }
                        }
                    }

                    // Удалить участника
                    Button(role: .destructive) {
                        showRemoveConfirmation = true
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .alert("Удалить участника?", isPresented: $showRemoveConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Вы уверены, что хотите удалить этого участника из чата?")
        }
    }

    private func roleDisplayName(_ role: ChatRole) -> String {
        switch role {
        case .owner:
            return "Владелец"
        case .admin:
            return "Администратор"
        case .member:
            return "Участник"
        }
    }
}

// MARK: - Add Member Row View
struct AddMemberRowView: View {
    let user: UserProfile
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                // Аватар
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

                // Имя и username
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChatSettingsView(chatId: "test")
}
