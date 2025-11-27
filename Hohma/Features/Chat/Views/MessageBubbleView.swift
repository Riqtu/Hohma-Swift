//
//  MessageBubbleView.swift
//  Hohma
//
//  Created by Artem Vydro on 30.10.2025.
//

import Inject
import SwiftUI

struct MessageBubbleView: View {
    @ObserveInjection var inject
    let message: ChatMessage
    let isCurrentUser: Bool
    let replyingToMessage: ChatMessage?  // Сообщение, на которое отвечают
    let onReply: () -> Void  // Callback для свайпа вправо
    let contextMenuBuilder: () -> AnyView?

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var htmlContentHeight: CGFloat = 50  // Начальная высота для HTML контента (будет обновлена автоматически)

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

                // Отображение сообщения, на которое отвечают
                if let replyingTo = replyingToMessage {
                    ReplyPreviewView(
                        replyingToMessage: replyingTo,
                        isCurrentUser: isCurrentUser
                    )
                }

                // Вложения (изображения или файлы)
                if !message.attachments.isEmpty {
                    VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                        ForEach(Array(message.attachments.enumerated()), id: \.offset) {
                            index, urlString in
                            if let url = URL(string: urlString) {
                                AttachmentView(
                                    url: url,
                                    messageType: message.messageType,
                                    isCurrentUser: isCurrentUser,
                                    messageId: message.id,
                                    attachmentIndex: index
                                )
                            }
                        }
                    }
                }

                // Текст сообщения (если есть и нет видео/аудио вложений)
                if !message.content.isEmpty && message.messageType != .system
                    && !hasVideoOrAudioAttachments
                {
                    Group {
                        if isHTMLContent(message.content) {
                            // HTML контент
                            HTMLMessageView(
                                htmlContent: message.content,
                                isCurrentUser: isCurrentUser,
                                contentHeight: $htmlContentHeight
                            )
                            .frame(height: max(htmlContentHeight, 20))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                        } else {
                            // Обычный текст
                            Text(message.content)
                                .font(.body)
                                .foregroundColor(isCurrentUser ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    isCurrentUser ? Color("AccentColor") : Color(.systemGray5)
                                )
                                .cornerRadius(16)
                        }
                    }
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
            .frame(
                maxWidth: isHTMLContent(message.content) && !message.content.isEmpty
                    && message.messageType != .system && !hasVideoOrAudioAttachments
                    ? UIScreen.main.bounds.width * 0.9
                    : UIScreen.main.bounds.width * 0.75,
                alignment: (isHTMLContent(message.content) && !message.content.isEmpty
                    && message.messageType != .system && !hasVideoOrAudioAttachments)
                    ? .center
                    : (isCurrentUser ? .trailing : .leading))

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
        .offset(x: isDragging ? dragOffset.width : 0)
        .modifier(ContextMenuWrapper(builder: contextMenuBuilder))
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Сначала проверяем направление движения
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)

                    // Если вертикальное движение больше или равно горизонтальному - не обрабатываем
                    // Это позволяет скроллу работать
                    if verticalDistance >= horizontalDistance {
                        isDragging = false
                        dragOffset = .zero
                        return
                    }

                    // Разрешаем свайп ВЛЕВО только если:
                    // 1. Движение влево (width < 0)
                    // 2. Горизонтальное движение значительно больше вертикального (ratio > 2.0)
                    // 3. Ограничиваем максимальное смещение до 60px
                    if value.translation.width < 0 && horizontalDistance > verticalDistance * 2.0 {
                        isDragging = true
                        let maxOffset: CGFloat = 60
                        dragOffset = CGSize(
                            width: max(value.translation.width, -maxOffset),
                            height: 0
                        )
                    } else {
                        isDragging = false
                        dragOffset = .zero
                    }
                }
                .onEnded { value in
                    // Если жест не был активен (вертикальный скролл) - ничего не делаем
                    guard isDragging else {
                        dragOffset = .zero
                        return
                    }

                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)

                    // Если свайпнули влево больше чем на 40px и движение горизонтальное - вызываем callback
                    if value.translation.width < -40 && horizontalDistance > verticalDistance * 2.0
                    {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                            isDragging = false
                        }
                        onReply()
                    } else {
                        // Возвращаем обратно
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                            isDragging = false
                        }
                    }
                }
        )
        .enableInjection()
    }

    private var hasVideoOrAudioAttachments: Bool {
        return message.attachments.contains { urlString in
            guard let url = URL(string: urlString) else { return false }
            let ext = url.pathExtension.lowercased()
            let isVideo = ["mp4", "mov", "m4v"].contains(ext)
            let isAudio = ["m4a", "aac", "mp3", "wav", "caf"].contains(ext)
            return isVideo || isAudio
        }
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

// MARK: - Reply Preview View
struct ReplyPreviewView: View {
    let replyingToMessage: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Вертикальная линия слева
            Rectangle()
                .fill(isCurrentUser ? Color.white.opacity(0.5) : Color.accentColor)
                .frame(width: 2)
                .cornerRadius(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(replyingToMessage.sender?.displayName ?? "Пользователь")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentUser ? Color.white.opacity(0.8) : Color.primary)
                    .lineLimit(1)

                if !replyingToMessage.content.isEmpty && replyingToMessage.messageType == .text {
                    Text(replyingToMessage.content)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(isCurrentUser ? Color.white.opacity(0.7) : Color.secondary)
                } else if !replyingToMessage.attachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: getAttachmentIcon())
                            .font(.caption2)
                        Text(getAttachmentText())
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(isCurrentUser ? Color.white.opacity(0.7) : Color.secondary)
                }
            }
        }
        .frame(maxWidth: 200, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrentUser ? Color.white.opacity(0.2) : Color(.systemGray5))
        )
    }

    private func getAttachmentIcon() -> String {
        if replyingToMessage.messageType == .image {
            return "photo"
        } else if replyingToMessage.attachments.contains(where: { urlString in
            guard let url = URL(string: urlString) else { return false }
            let ext = url.pathExtension.lowercased()
            return ["m4a", "aac", "mp3", "wav", "caf"].contains(ext)
        }) {
            return "mic.fill"
        } else if replyingToMessage.attachments.contains(where: { urlString in
            guard let url = URL(string: urlString) else { return false }
            let ext = url.pathExtension.lowercased()
            return ["mp4", "mov", "m4v"].contains(ext)
        }) {
            return "video.fill"
        } else {
            return "doc"
        }
    }

    private func getAttachmentText() -> String {
        if replyingToMessage.messageType == .image {
            return "Фото"
        } else if replyingToMessage.attachments.contains(where: { urlString in
            guard let url = URL(string: urlString) else { return false }
            let ext = url.pathExtension.lowercased()
            return ["m4a", "aac", "mp3", "wav", "caf"].contains(ext)
        }) {
            return "Голосовое сообщение"
        } else if replyingToMessage.attachments.contains(where: { urlString in
            guard let url = URL(string: urlString) else { return false }
            let ext = url.pathExtension.lowercased()
            return ["mp4", "mov", "m4v"].contains(ext)
        }) {
            return "Видеосообщение"
        } else {
            return "Файл"
        }
    }
}

// MARK: - Attachment View
struct AttachmentView: View {
    let url: URL
    let messageType: MessageType
    let isCurrentUser: Bool
    let messageId: String
    let attachmentIndex: Int
    @State private var showFullScreen = false

    private var isVoiceMessage: Bool {
        let ext = url.pathExtension.lowercased()
        return ["m4a", "aac", "mp3", "wav", "caf"].contains(ext)
    }

    private var isVideoMessage: Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v"].contains(ext)
    }

    var body: some View {
        Group {
            if isVoiceMessage {
                // Голосовое сообщение с плеером
                VoiceMessagePlayerView(url: url, isCurrentUser: isCurrentUser)
            } else if isVideoMessage {
                // Видеосообщение (кружок) с плеером
                VideoMessagePlayerView(
                    messageId: "\(messageId)-\(attachmentIndex)",
                    url: url,
                    isCurrentUser: isCurrentUser
                )
            } else {
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

private struct ContextMenuWrapper: ViewModifier {
    let builder: () -> AnyView?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let menu = builder() {
            content.contextMenu {
                menu
            }
        } else {
            content
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
            MessageBubbleView(
                message: message1,
                isCurrentUser: false,
                replyingToMessage: nil,
                onReply: {},
                contextMenuBuilder: { nil }
            )
        }

        if let message2 = message2 {
            MessageBubbleView(
                message: message2,
                isCurrentUser: true,
                replyingToMessage: nil,
                onReply: {},
                contextMenuBuilder: {
                    AnyView(
                        Button(role: .destructive) {} label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    )
                }
            )
        }
    }
    .padding()
}
