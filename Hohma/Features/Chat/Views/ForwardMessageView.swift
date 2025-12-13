//
//  ForwardMessageView.swift
//  Hohma
//
//  Created by Assistant on 27.01.2025.
//

import Foundation
import Inject
import SwiftUI

/// View для выбора чата при пересылке сообщения
struct ForwardMessageView: View {
    @ObserveInjection var inject
    
    let message: ChatMessage
    let currentChatId: String  // ID текущего чата, чтобы исключить его из списка
    let onDismiss: () -> Void
    
    @StateObject private var chatListViewModel = ChatListViewModel(autoLoad: false)
    @State private var errorMessage: String?
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if chatListViewModel.isLoading && chatListViewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка чатов...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableChats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Нет чатов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Нет других чатов для пересылки")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(availableChats, id: \.id) { chat in
                            Button(action: {
                                forwardToChat(chatId: chat.id)
                            }) {
                                ChatCellView(chat: chat)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isSending)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 20))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listStyle(.plain)
                }
            }
            .appBackground()
            .navigationTitle("Переслать сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        onDismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                // Всегда загружаем чаты при открытии sheet
                chatListViewModel.loadChats()
            }
        }
        .enableInjection()
    }
    
    // Исключаем текущий чат из списка
    private var availableChats: [Chat] {
        chatListViewModel.chats.filter { $0.id != currentChatId }
    }
    
    private func forwardToChat(chatId: String) {
        guard !isSending else { return }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                // Создаем запрос для пересылки сообщения
                // Используем текущий чат как источник пересылки, если сообщение еще не переслано
                // Иначе используем оригинальный источник
                let sourceChatId = message.forwardedFromChatId ?? currentChatId
                
                let request = SendMessageRequest(
                    chatId: chatId,
                    content: message.content,
                    messageType: message.messageType,
                    attachments: message.attachments.isEmpty ? nil : message.attachments,
                    replyToId: nil,  // При пересылке не сохраняем replyToId
                    battleId: message.battleId,
                    raceId: message.raceId,
                    wheelId: message.wheelId,
                    forwardedFromChatId: sourceChatId
                )
                
                _ = try await ChatService.shared.sendMessage(request)
                
                await MainActor.run {
                    isSending = false
                    onDismiss()
                    
                    // Отправляем уведомление для навигации к целевому чату
                    // Используем небольшую задержку, чтобы sheet успел закрыться
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 секунды
                        NotificationCenter.default.post(
                            name: .navigationRequested,
                            object: nil,
                            userInfo: [
                                "destination": "chat",
                                "chatId": chatId
                            ]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = ErrorHandler.shared.handle(error, context: "forwardMessage", category: .general)
                }
            }
        }
    }
}

