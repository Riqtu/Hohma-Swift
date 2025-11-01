//
//  ChatView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Inject
import SwiftUI
import UIKit

struct ChatView: View {
    @ObserveInjection var inject
    let chatId: String
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageToDelete: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Messages
            messagesView

            // Input
            messageInputView
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.loadChat(chatId: chatId)
        }
        .onDisappear {
            viewModel.leaveChat()
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Удалить сообщение?", isPresented: .constant(messageToDelete != nil)) {
            Button("Отмена", role: .cancel) {
                messageToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                if let messageId = messageToDelete {
                    viewModel.deleteMessage(messageId: messageId)
                    messageToDelete = nil
                }
            }
        } message: {
            Text("Вы уверены, что хотите удалить это сообщение?")
        }
        .enableInjection()
    }
}

// MARK: - ScrollView with Auto Scroll
// Сообщения идут сверху вниз, прокрутка к последнему сообщению
struct ScrollViewWithAutoScrollTracker: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMoreMessages: Bool
    let currentUserId: String?
    let onLoadMore: () -> Void
    let onDeleteMessage: ((String) -> Void)?

    @State private var firstMessageId: String? = nil
    @State private var scrollPosition: CGFloat = 0
    @State private var savedFirstMessageId: String? = nil  // Сохраняем ID первого сообщения перед загрузкой
    @State private var lastLoadMoreTime: Date? = nil  // Защита от множественных вызовов
    @State private var lastMessageId: String? = nil  // Отслеживаем последнее сообщение для автоскролла
    @State private var hasScrolledToBottom = false  // Флаг для отслеживания начальной прокрутки

    var body: some View {
        SwiftUI.ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Индикатор загрузки в начале списка (для предыдущих сообщений)
                    if isLoadingMore && hasMoreMessages {
                        ProgressView()
                            .padding()
                            .id("loading-more")
                    }

                    if isLoading && messages.isEmpty {
                        ProgressView()
                            .padding()
                            .id("loading")
                    }

                    // Сообщения в обычном порядке (сверху вниз)
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isCurrentUser: message.senderId == currentUserId
                        )
                        .id(message.id)
                        .contextMenu {
                            // Показываем контекстное меню только для своих сообщений
                            if message.senderId == currentUserId, let onDelete = onDeleteMessage {
                                Button(role: .destructive) {
                                    onDelete(message.id)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                        .onAppear {
                            // Отслеживаем появление первого сообщения для загрузки предыдущих
                            if message.id == messages.first?.id && hasMoreMessages && !isLoadingMore
                                && !isLoading
                            {
                                // Защита от множественных вызовов
                                let now = Date()
                                if let lastTime = lastLoadMoreTime,
                                    now.timeIntervalSince(lastTime) < 0.5
                                {
                                    return
                                }
                                lastLoadMoreTime = now

                                // Сохраняем ID первого сообщения перед загрузкой
                                savedFirstMessageId = message.id
                                onLoadMore()
                            }
                        }
                    }

                    // Невидимый маркер внизу для прокрутки
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                // Отслеживаем позицию прокрутки
                scrollPosition = offset

                // Резервный механизм: если прокрутили близко к началу (offset > -100), загружаем больше
                // Это работает как дополнительная защита, если onAppear первого сообщения не сработал
                if offset > -100 && hasMoreMessages && !isLoadingMore && !isLoading
                    && !messages.isEmpty
                {
                    let now = Date()
                    if let lastTime = lastLoadMoreTime, now.timeIntervalSince(lastTime) < 0.5 {
                        return
                    }
                    lastLoadMoreTime = now

                    // Только если еще не загружаем (savedFirstMessageId == nil)
                    if savedFirstMessageId == nil {
                        savedFirstMessageId = messages.first?.id
                        onLoadMore()
                    }
                }
            }
            .onAppear {
                // При открытии чата сбрасываем флаг прокрутки
                hasScrolledToBottom = false
                firstMessageId = messages.first?.id
                lastMessageId = messages.last?.id

                // Прокручиваем только если сообщения уже загружены
                if !messages.isEmpty && !isLoading {
                    // Небольшая задержка для того, чтобы view успел отрендериться
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy, animated: false)
                        hasScrolledToBottom = true
                    }
                }
            }
            .onChange(of: isLoadingMore) { _, isCurrentlyLoadingMore in
                // После загрузки предыдущих сообщений возвращаемся к сохраненному сообщению
                if !isCurrentlyLoadingMore && !messages.isEmpty, let savedId = savedFirstMessageId {
                    // Проверяем, что сообщение все еще существует
                    if messages.contains(where: { $0.id == savedId }) {
                        // Прокручиваем к сохраненному сообщению для сохранения позиции
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.none) {
                                proxy.scrollTo(savedId, anchor: .top)
                            }
                        }
                    }
                    savedFirstMessageId = nil
                    firstMessageId = messages.first?.id
                }
            }
            .onChange(of: messages.count) { oldCount, newCount in
                // Если это первая загрузка (было 0 сообщений), прокручиваем вниз после небольшой задержки
                if oldCount == 0 && newCount > 0 {
                    firstMessageId = messages.first?.id
                    lastMessageId = messages.last?.id
                    // Ждем окончания загрузки, прокрутка будет в onChange(isLoading)
                    return
                }

                guard newCount > oldCount, let newLastMessage = messages.last else { return }

                // Если загружаются предыдущие сообщения (в начале списка), не прокручиваем автоматически
                if savedFirstMessageId != nil {
                    // Позиция будет восстановлена в onChange(isLoadingMore)
                    return
                }

                // Проверяем, было ли добавлено новое сообщение в конец (новое последнее сообщение)
                let isNewMessageAtEnd = newLastMessage.id != lastMessageId

                // При добавлении нового сообщения в конец прокручиваем вниз
                // Всегда скроллим к новым сообщениям если:
                // 1. Это сообщение текущего пользователя (свои сообщения)
                // 2. Пользователь близко к низу (в пределах 500 пунктов от низа)
                let isCurrentUserMessage = newLastMessage.senderId == currentUserId

                if isNewMessageAtEnd && !isLoading && !isLoadingMore {
                    lastMessageId = newLastMessage.id

                    // Если это сообщение текущего пользователя - всегда скроллим
                    // Или если пользователь близко к низу
                    if isCurrentUserMessage || abs(scrollPosition) < 500 {
                        // Автоматически прокручиваем к новому сообщению
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(newLastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .onChange(of: isLoading) { _, isCurrentlyLoading in
                // После первой загрузки сообщений прокручиваем вниз
                if !isCurrentlyLoading && !messages.isEmpty && !hasScrolledToBottom {
                    // Обновляем lastMessageId
                    lastMessageId = messages.last?.id
                    // Увеличиваем задержку после загрузки для более надежной прокрутки
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy, animated: false)
                        hasScrolledToBottom = true
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        // Обновляем lastMessageId
        lastMessageId = messages.last?.id

        // Для начальной прокрутки используем больше задержки, чтобы LazyVStack успел отрендериться
        let delay: TimeInterval = hasScrolledToBottom ? 0.1 : 0.5

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Проверяем, что сообщения все еще есть (на случай если они были удалены)
            guard !self.messages.isEmpty else { return }

            let targetId = self.messages.last?.id ?? "bottom"

            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(targetId, anchor: .bottom)
                }
            } else {
                // Для начальной прокрутки пробуем несколько раз для надежности
                proxy.scrollTo(targetId, anchor: .bottom)

                // Повторная попытка через небольшую задержку для надежности
                if !self.hasScrolledToBottom {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo(targetId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

extension ChatView {
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // Avatar
            AsyncImage(url: URL(string: viewModel.displayAvatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(
                    systemName: viewModel.isPrivateChat
                        ? "person.circle.fill" : "person.2.circle.fill"
                )
                .resizable()
                .foregroundColor(.secondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayName)
                    .font(.headline)

                if !viewModel.typingUsers.isEmpty {
                    Text("Печатает...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - Messages View
    private var messagesView: some View {
        ScrollViewWithAutoScrollTracker(
            messages: viewModel.messages,
            isLoading: viewModel.isLoadingMessages,
            isLoadingMore: viewModel.isLoadingMoreMessages,
            hasMoreMessages: viewModel.hasMoreMessages,
            currentUserId: viewModel.currentUserId,
            onLoadMore: {
                viewModel.loadMoreMessages()
            },
            onDeleteMessage: { messageId in
                messageToDelete = messageId
            }
        )
    }

    // MARK: - Message Input View
    private var messageInputView: some View {
        HStack(spacing: 12) {
            TextField("Введите сообщение...", text: $viewModel.messageInput, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(22)
                .lineLimit(1...5)
                .onChange(of: viewModel.messageInput) { _, newValue in
                    if !newValue.isEmpty {
                        viewModel.startTyping()
                    }
                }

            Button(action: {
                viewModel.sendMessage()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(
                        viewModel.messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty || viewModel.isSending
                            ? .gray
                            : .accentColor)
            }
            .disabled(
                viewModel.messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isSending)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}
