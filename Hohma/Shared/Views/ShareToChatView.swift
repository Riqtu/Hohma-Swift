//
//  ShareToChatView.swift
//  Hohma
//
//  Created by Assistant on 27.01.2025.
//

import Foundation
import Inject
import SwiftUI

/// Общий компонент для отправки контента (колесо, скачка, батл) в чат
struct ShareToChatView: View {
    @ObserveInjection var inject
    
    let title: String
    let emptyStateMessage: String
    let messageType: MessageType
    let itemId: String
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
                } else if chatListViewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Нет чатов")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(emptyStateMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(chatListViewModel.chats, id: \.id) { chat in
                            Button(action: {
                                sendToChat(chatId: chat.id)
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
            .navigationTitle(title)
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
    
    private func sendToChat(chatId: String) {
        guard !isSending else { return }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                let request = createSendMessageRequest(chatId: chatId)
                _ = try await ChatService.shared.sendMessage(request)
                
                await MainActor.run {
                    isSending = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = ErrorHandler.shared.handle(error, context: "sendToChat", category: .general)
                }
            }
        }
    }
    
    private func createSendMessageRequest(chatId: String) -> SendMessageRequest {
        var battleId: String? = nil
        var raceId: String? = nil
        var wheelId: String? = nil
        
        switch messageType {
        case .movieBattle:
            battleId = itemId
        case .race:
            raceId = itemId
        case .wheel:
            wheelId = itemId
        default:
            break
        }
        
        return SendMessageRequest(
            chatId: chatId,
            content: "",
            messageType: messageType,
            attachments: nil,
            replyToId: nil,
            battleId: battleId,
            raceId: raceId,
            wheelId: wheelId
        )
    }
}

