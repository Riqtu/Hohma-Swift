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
        .enableInjection()
    }
}

// MARK: - ScrollView with Auto Scroll
// Сообщения идут сверху вниз, прокрутка к последнему сообщению
struct ScrollViewWithAutoScrollTracker: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let currentUserId: String?

    var body: some View {
        SwiftUI.ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
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
                    }

                    // Невидимый маркер внизу для прокрутки
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // При открытии чата прокручиваем к последнему сообщению
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { oldCount, newCount in
                // При добавлении нового сообщения прокручиваем вниз
                if newCount > oldCount && !isLoading && !messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: isLoading) { _, isCurrentlyLoading in
                // После загрузки сообщений прокручиваем вниз
                if !isCurrentlyLoading && !messages.isEmpty {
                    // Увеличиваем задержку после загрузки для более надежной прокрутки
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Прокручиваем к последнему сообщению или к маркеру внизу
        let targetId = messages.last?.id ?? "bottom"

        // Используем небольшую задержку для того, чтобы ScrollView успел обновиться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(targetId, anchor: .bottom)
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
            currentUserId: viewModel.currentUserId
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
