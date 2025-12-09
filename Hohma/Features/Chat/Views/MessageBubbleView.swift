//
//  MessageBubbleView.swift
//  Hohma
//
//  Created by Artem Vydro on 30.10.2025.
//

import AVFoundation
import AVKit
import Inject
import SwiftUI

struct MessageBubbleView: View {
    @ObserveInjection var inject
    let message: ChatMessage
    let isCurrentUser: Bool
    let replyingToMessage: ChatMessage?  // Сообщение, на которое отвечают
    let onReply: () -> Void  // Callback для свайпа вправо
    let onReaction: (String) -> Void  // Callback для добавления/удаления реакции
    let contextMenuBuilder: () -> AnyView?
    let showAvatar: Bool
    let showSenderName: Bool
    let isGroupedWithPrev: Bool
    let isGroupedWithNext: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var htmlContentHeight: CGFloat = 50  // Начальная высота для HTML контента (будет обновлена автоматически)
    @State private var showReactionPicker: Bool = false
    @State private var showAlbumGallery: Bool = false

    var body: some View {
        // Системные сообщения отображаются по-особому
        if message.messageType == .system {
            systemMessageView
        } else {
            regularMessageView
        }
    }

    // MARK: - System Message View
    private var systemMessageView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                Text(formatDate(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Regular Message View
    private var regularMessageView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                if showAvatar {
                    // Avatar for other users (слева)
                    AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .id("avatar-\(message.senderId)-\(message.sender?.avatarUrl ?? "")")
                    .onAppear {
                        // Принудительная загрузка при появлении в viewport
                        if let avatarUrl = message.sender?.avatarUrl, !avatarUrl.isEmpty {
                            // Предзагрузка в кэш для улучшения производительности
                            Task {
                                if let url = URL(string: avatarUrl) {
                                    let request = URLRequest(
                                        url: url, cachePolicy: .returnCacheDataElseLoad)
                                    _ = try? await URLSession.shared.data(for: request)
                                }
                            }
                        }
                    }
                } else {
                    // Резервируем место под аватарку, чтобы выравнивание не прыгало
                    Spacer().frame(width: 30, height: 30)
                }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser, showSenderName {
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

                // Стикер
                if message.messageType == .sticker, let stickerUrl = message.attachments.first,
                    let url = URL(string: stickerUrl)
                {
                    let isAnimated = isAnimatedSticker(url: url)
                    StickerView(url: url, isAnimated: isAnimated, isCurrentUser: isCurrentUser)
                }

                // Вложения (изображения или файлы)
                if !message.attachments.isEmpty && message.messageType != .sticker {
                    let isAlbum = message.attachments.count > 1
                    let hasVideoMessage = message.attachments.contains { urlString in
                        guard let url = URL(string: urlString) else { return false }
                        let ext = url.pathExtension.lowercased()
                        return message.messageType == .file && ["mp4", "mov", "m4v"].contains(ext)
                    }

                    Group {
                        if isAlbum {
                            // Компактный вид для альбомов
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4),
                                ],
                                spacing: 4
                            ) {
                                ForEach(Array(message.attachments.enumerated()), id: \.offset) {
                                    index, urlString in
                                    if let url = URL(string: urlString) {
                                        AttachmentView(
                                            url: url,
                                            messageType: message.messageType,
                                            isCurrentUser: isCurrentUser,
                                            messageId: message.id,
                                            attachmentIndex: index,
                                            isCompact: true
                                        )
                                        .onAppear {
                                            // Предзагрузка изображений в альбоме при появлении
                                            if message.messageType == .image {
                                                Task {
                                                    let request = URLRequest(
                                                        url: url,
                                                        cachePolicy: .returnCacheDataElseLoad)
                                                    _ = try? await URLSession.shared.data(
                                                        for: request)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(12)
                            .frame(maxWidth: 280)  // Ограничиваем максимальную ширину альбома
                            .contentShape(Rectangle())  // Делаем всю область кликабельной
                            .onTapGesture {
                                showAlbumGallery = true
                            }
                            .sheet(isPresented: $showAlbumGallery) {
                                AlbumGalleryView(
                                    attachments: message.attachments,
                                    messageType: message.messageType
                                )
                            }
                        } else {
                            // Обычный вид для одного вложения
                            // Не применяем фон для видеосообщений
                            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                                ForEach(Array(message.attachments.enumerated()), id: \.offset) {
                                    index, urlString in
                                    if let url = URL(string: urlString) {
                                        AttachmentView(
                                            url: url,
                                            messageType: message.messageType,
                                            isCurrentUser: isCurrentUser,
                                            messageId: message.id,
                                            attachmentIndex: index,
                                            isCompact: false
                                        )
                                    }
                                }
                            }
                            .padding(hasVideoMessage ? 0 : 8)
                            .background(
                                hasVideoMessage ? Color.clear : Color(.systemGray6).opacity(0.5)
                            )
                            .cornerRadius(hasVideoMessage ? 0 : 12)
                        }
                    }
                }

                // Текст сообщения (если есть и нет видео/аудио вложений и не стикер)
                if !message.content.isEmpty && message.messageType != .system
                    && message.messageType != .sticker
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

                // Реакции
                if let reactions = message.reactions, !reactions.isEmpty {
                    ReactionsView(
                        reactions: reactions,
                        currentUserId: TRPCService.shared.currentUser?.id,
                        onReactionTap: { emoji in
                            onReaction(emoji)
                        }
                    )
                    .padding(.top, 4)
                }

                HStack(spacing: 4) {
                    Text(formatDate(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isCurrentUser {
                        if isPendingMessage {
                            // Индикатор отправки для временных сообщений
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                        } else if message.status == .read {
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
                .padding(.top, message.reactions?.isEmpty == false ? 2 : 0)
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
                if showAvatar {
                    // Avatar for current user (справа)
                    AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .id("avatar-\(message.senderId)-\(message.sender?.avatarUrl ?? "")")
                    .onAppear {
                        // Принудительная загрузка при появлении в viewport
                        if let avatarUrl = message.sender?.avatarUrl, !avatarUrl.isEmpty {
                            // Предзагрузка в кэш для улучшения производительности
                            Task {
                                if let url = URL(string: avatarUrl) {
                                    let request = URLRequest(
                                        url: url, cachePolicy: .returnCacheDataElseLoad)
                                    _ = try? await URLSession.shared.data(for: request)
                                }
                            }
                        }
                    }
                } else {
                    Spacer().frame(width: 30, height: 30)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 4)
        .offset(x: isDragging ? dragOffset.width : 0)
        .modifier(ContextMenuWrapper(builder: contextMenuBuilder))
        .onLongPressGesture {
            showReactionPicker = true
        }
        .sheet(isPresented: $showReactionPicker) {
            ReactionPickerView(
                message: message,
                onReactionSelected: { emoji in
                    onReaction(emoji)
                    showReactionPicker = false
                }
            )
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)  // Увеличиваем минимальное расстояние для лучшего распознавания
                .onChanged { value in
                    // Сначала проверяем направление движения
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)

                    // Если вертикальное движение больше горизонтального - не обрабатываем
                    // Это позволяет скроллу работать без конфликтов
                    if verticalDistance > horizontalDistance {
                        isDragging = false
                        dragOffset = .zero
                        return
                    }

                    // Разрешаем свайп ВЛЕВО только если:
                    // 1. Движение влево (width < 0)
                    // 2. Горизонтальное движение значительно больше вертикального (ratio > 3.0 для более строгой проверки)
                    // 3. Ограничиваем максимальное смещение до 60px
                    if value.translation.width < 0 && horizontalDistance > verticalDistance * 3.0 {
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
                    if value.translation.width < -40 && horizontalDistance > verticalDistance * 3.0
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

    private func isAnimatedSticker(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        // Определяем анимированные стикеры по расширению
        return ["gif", "webp"].contains(ext) || url.absoluteString.contains("animated")
    }

    private var isPendingMessage: Bool {
        // Проверяем, является ли сообщение временным (отправляется)
        return message.id.hasPrefix("temp-")
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
    let isCompact: Bool  // Компактный режим для альбомов
    @State private var showFullScreen = false
    @State private var showFullScreenVideo = false

    init(
        url: URL, messageType: MessageType, isCurrentUser: Bool, messageId: String,
        attachmentIndex: Int, isCompact: Bool = false
    ) {
        self.url = url
        self.messageType = messageType
        self.isCurrentUser = isCurrentUser
        self.messageId = messageId
        self.attachmentIndex = attachmentIndex
        self.isCompact = isCompact
    }

    private var isVoiceMessage: Bool {
        let ext = url.pathExtension.lowercased()
        return ["m4a", "aac", "mp3", "wav", "caf"].contains(ext)
    }

    private var isVideoMessage: Bool {
        // Видеосообщение определяется по:
        // 1. Типу сообщения - .file (видеосообщения отправляются как .file)
        // 2. Количеству вложений - одно вложение (видеосообщения всегда одно)
        // 3. Формату файла - видео формат
        let ext = url.pathExtension.lowercased()
        let isVideoFormat = ["mp4", "mov", "m4v"].contains(ext)

        // Видеосообщение - это сообщение типа .file с одним видео вложением
        // (в отличие от альбомов, которые отправляются как .image)
        return messageType == .file && isVideoFormat
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
                // Проверяем, является ли это видео (но не видеосообщением)
                let isRegularVideo =
                    !isVideoMessage
                    && {
                        let ext = url.pathExtension.lowercased()
                        return ["mp4", "mov", "m4v"].contains(ext)
                    }()

                if isRegularVideo {
                    // Обычное видео из галереи - отображаем как видео (не в кружке)
                    // В компактном режиме не добавляем обработчики - галерея откроется при нажатии на альбом
                    RegularVideoPlayerView(url: url, isCompact: isCompact, autoPlay: false)
                        .allowsHitTesting(!isCompact)  // В компактном режиме отключаем обработку нажатий
                        .onTapGesture {
                            if !isCompact {
                                showFullScreenVideo = true
                            }
                        }
                        .sheet(isPresented: $showFullScreenVideo) {
                            FullScreenVideoView(url: url)
                        }
                } else {
                    switch messageType {
                    case .image:
                        // Изображение с возможностью просмотра (с кешированием)
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: isCompact ? nil : 250, height: isCompact ? 150 : 300
                                )
                                .frame(
                                    maxWidth: isCompact ? .infinity : 280,  // Ограничиваем максимальную ширину
                                    maxHeight: isCompact ? 150 : 300
                                )
                                .clipped()
                                .cornerRadius(isCompact ? 8 : 12)
                                .allowsHitTesting(!isCompact)  // В компактном режиме отключаем обработку нажатий
                                .onTapGesture {
                                    if !isCompact {
                                        showFullScreen = true
                                    }
                                }
                        } placeholder: {
                            ProgressView()
                                .frame(
                                    width: isCompact ? 150 : 200, height: isCompact ? 150 : 200)
                        }
                        .id(url.absoluteString)
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
    }

    private func preloadImage(url: URL) {
        // Предзагрузка изображения в кэш для улучшения производительности
        Task {
            _ = try? await ImageCacheService.shared.loadImage(from: url)
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

                CachedAsyncImage(url: url) { image in
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
                } placeholder: {
                    ProgressView()
                        .tint(.white)
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

// MARK: - Full Screen Video View
struct FullScreenVideoView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear {
                            player.play()
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
}

// MARK: - Album Gallery View
struct AlbumGalleryView: View {
    let attachments: [String]
    let messageType: MessageType
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, urlString in
                        if let url = URL(string: urlString) {
                            AlbumItemView(url: url, messageType: messageType)
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(currentIndex + 1) / \(attachments.count)")
                        .foregroundColor(.white)
                }
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

// MARK: - Album Item View
struct AlbumItemView: View {
    let url: URL
    let messageType: MessageType
    @State private var scale: CGFloat = 1.0
    @State private var player: AVPlayer?

    private var isVideo: Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v"].contains(ext)
    }

    var body: some View {
        ZStack {
            if isVideo {
                // Видео
                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear {
                            player.play()
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                        .onAppear {
                            player = AVPlayer(url: url)
                            player?.play()
                        }
                }
            } else {
                // Изображение
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
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Sticker View
private struct StickerView: View {
    let url: URL
    let isAnimated: Bool
    let isCurrentUser: Bool

    var body: some View {
        AnimatedStickerView(url: url, isAnimated: isAnimated, size: CGSize(width: 120, height: 120))
            .frame(width: 120, height: 120, alignment: .center)
            .background(Color.clear)
            .contentShape(Rectangle())  // Делаем всю область кликабельной
            .clipped()  // Обрезаем содержимое по границам
            .aspectRatio(contentMode: .fit)  // Сохраняем пропорции
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

    VStack {
        if let message1 = message1 {
            MessageBubbleView(
                message: message1,
                isCurrentUser: false,
                replyingToMessage: nil,
                onReply: {},
                onReaction: { _ in },
                contextMenuBuilder: { nil },
                showAvatar: true,
                showSenderName: true,
                isGroupedWithPrev: false,
                isGroupedWithNext: false
            )
        }

        if let message2 = message2 {
            MessageBubbleView(
                message: message2,
                isCurrentUser: true,
                replyingToMessage: nil,
                onReply: {},
                onReaction: { _ in },
                contextMenuBuilder: {
                    AnyView(
                        Button(role: .destructive) {
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    )
                },
                showAvatar: true,
                showSenderName: true,
                isGroupedWithPrev: false,
                isGroupedWithNext: false
            )
        }
    }
    .padding()
}

// MARK: - Video Thumbnail Cache
private actor VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private var cache: [URL: UIImage] = [:]

    func getThumbnail(for url: URL) -> UIImage? {
        return cache[url]
    }

    func setThumbnail(_ image: UIImage, for url: URL) {
        cache[url] = image
        if cache.count > 50 {
            let firstKey = cache.keys.first
            if let key = firstKey {
                cache.removeValue(forKey: key)
            }
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    func getCacheSize() -> Int {
        return cache.count
    }
}

// MARK: - Regular Video Player View (для обычных видео из галереи)
struct RegularVideoPlayerView: View {
    let url: URL
    let isCompact: Bool
    let autoPlay: Bool
    @State private var player: AVPlayer?
    @State private var thumbnail: UIImage?
    @State private var isHorizontal: Bool = false

    init(url: URL, isCompact: Bool = false, autoPlay: Bool = true) {
        self.url = url
        self.isCompact = isCompact
        self.autoPlay = autoPlay
    }

    var body: some View {
        VStack(spacing: 8) {
            // Превью видео с кнопкой воспроизведения
            ZStack {
                if let thumbnail = thumbnail {
                    // Показываем превью
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: isCompact ? 150 : 200)
                        .frame(maxWidth: isHorizontal && !isCompact ? 280 : nil)  // Ограничиваем ширину горизонтальных видео
                        .clipped()
                        .cornerRadius(isCompact ? 8 : 12)
                        .overlay(
                            // Кнопка воспроизведения поверх превью
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                        )
                } else {
                    // Показываем плейсхолдер пока загружается превью
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                        .fill(Color(.systemGray5))
                        .frame(height: isCompact ? 150 : 200)
                        .frame(maxWidth: !isCompact ? 280 : nil)  // Ограничиваем ширину по умолчанию
                        .overlay(
                            VStack {
                                ProgressView()
                                    .tint(.white)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: isCompact ? 40 : 50))
                                    .foregroundColor(.white)
                                if !isCompact {
                                    Text("Видео")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        )
                }
            }
        }
        .onAppear {
            if autoPlay {
                loadAndPlay()
            } else {
                generateThumbnail()
            }
        }
    }

    private func loadAndPlay() {
        if player == nil {
            player = AVPlayer(url: url)
            player?.play()
        }
    }

    private func generateThumbnail() {
        // Проверяем кэш сначала
        Task {
            if let cachedThumbnail = await VideoThumbnailCache.shared.getThumbnail(for: url) {
                await MainActor.run {
                    self.thumbnail = cachedThumbnail
                    self.isHorizontal = cachedThumbnail.size.width > cachedThumbnail.size.height
                }
                return
            }

            // Генерируем превью асинхронно, не блокируя UI
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceAfter = .zero
            imageGenerator.requestedTimeToleranceBefore = .zero
            // Уменьшаем размер превью для лучшей производительности
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)

            do {
                let cgImage = try await imageGenerator.image(at: CMTime.zero).image
                let thumbnailImage = UIImage(cgImage: cgImage)

                // Сохраняем в кэш
                await VideoThumbnailCache.shared.setThumbnail(thumbnailImage, for: url)

                await MainActor.run {
                    self.thumbnail = thumbnailImage
                    // Определяем ориентацию по размеру превью
                    self.isHorizontal = thumbnailImage.size.width > thumbnailImage.size.height
                }
            } catch {
                print("❌ Failed to generate thumbnail: \(error)")
            }
        }
    }
}
