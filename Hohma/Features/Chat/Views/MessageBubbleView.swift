//
//  MessageBubbleView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Inject
import SwiftUI

struct MessageBubbleView: View {
    @ObserveInjection var inject
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                // Avatar for other users (слева)
                AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.sender?.displayName ?? "Пользователь")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Вложения (изображения или файлы)
                if !message.attachments.isEmpty {
                    VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                        ForEach(Array(message.attachments.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                AttachmentView(url: url, messageType: message.messageType)
                            }
                        }
                    }
                }

                // Текст сообщения (если есть)
                if !message.content.isEmpty && message.messageType != .system {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color("AccentColor") : Color(.systemGray5))
                        .cornerRadius(16)
                }

                HStack(spacing: 4) {
                    Text(formatDate(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isCurrentUser {
                        if message.status == .read {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if message.status == .delivered {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity * 0.75, alignment: isCurrentUser ? .trailing : .leading)

            if isCurrentUser {
                // Avatar for current user (справа)
                AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 4)
        .enableInjection()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                formatter.dateFormat = "HH:mm"
                return formatter.string(from: date)
            } else {
                formatter.dateFormat = "dd.MM HH:mm"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

// MARK: - Attachment View
struct AttachmentView: View {
    let url: URL
    let messageType: MessageType
    @State private var showFullScreen = false
    
    var body: some View {
        Group {
            switch messageType {
            case .image:
                // Изображение с возможностью просмотра
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 200, height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 250, maxHeight: 300)
                            .cornerRadius(12)
                            .onTapGesture {
                                showFullScreen = true
                            }
                    case .failure:
                        Image(systemName: "photo")
                            .frame(width: 200, height: 200)
                            .foregroundColor(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .sheet(isPresented: $showFullScreen) {
                    FullScreenImageView(url: url)
                }
            case .file:
                // Файл с иконкой и возможностью скачать
                Button(action: {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: getFileIcon(for: url))
                            .font(.title2)
                        Text(url.lastPathComponent)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            default:
                EmptyView()
            }
        }
    }
    
    private func getFileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "txt": return "text.alignleft"
        case "zip": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = value
                                    }
                                    .onEnded { _ in
                                        withAnimation {
                                            scale = max(1.0, min(scale, 3.0))
                                        }
                                    }
                            )
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    let message1JSON = """
        {
            "id": "1",
            "chatId": "chat1",
            "senderId": "user1",
            "content": "Привет! Как дела?",
            "messageType": "TEXT",
            "attachments": [],
            "status": "SENT",
            "createdAt": "2025-10-30T12:00:00.000Z",
            "updatedAt": "2025-10-30T12:00:00.000Z"
        }
        """

    let message2JSON = """
        {
            "id": "2",
            "chatId": "chat1",
            "senderId": "user2",
            "content": "Все отлично, спасибо!",
            "messageType": "TEXT",
            "attachments": [],
            "status": "READ",
            "createdAt": "2025-10-30T12:01:00.000Z",
            "updatedAt": "2025-10-30T12:01:00.000Z"
        }
        """

    let decoder = JSONDecoder()
    let message1 = try? decoder.decode(ChatMessage.self, from: message1JSON.data(using: .utf8)!)
    let message2 = try? decoder.decode(ChatMessage.self, from: message2JSON.data(using: .utf8)!)

    return VStack {
        if let message1 = message1 {
            MessageBubbleView(message: message1, isCurrentUser: false)
        }

        if let message2 = message2 {
            MessageBubbleView(message: message2, isCurrentUser: true)
        }
    }
    .padding()
}
