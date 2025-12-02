//
//  ChatView.swift
//  Hohma
//
//  Created by Artem Vydro on 30.10.2025.
//

import AVFoundation
import Inject
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @ObserveInjection var inject
    let chatId: String
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageToDelete: String? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showSettings = false
    @State private var chatBackgroundUrl: String? = nil

    var body: some View {
        ZStack {
            // Фон чата - используем GeometryReader для ограничения размера
            if let backgroundUrl = chatBackgroundUrl {
                GeometryReader { geometry in
                    AsyncImage(url: URL(string: backgroundUrl)) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.1)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure:
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                }
                .allowsHitTesting(false)  // Фон не должен перехватывать нажатия
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Messages
                messagesView

                // Input
                messageInputView
            }

            // Overlay для записи видеосообщения на полный экран
            if viewModel.isRecordingVideo {
                VideoRecordOverlayView(
                    duration: viewModel.videoRecordingDuration,
                    previewLayer: viewModel.videoRecorder.previewLayer,
                    isFrontCamera: viewModel.videoRecorder.isFrontCamera,
                    showControls: viewModel.showVideoControls,
                    onCancel: {
                        viewModel.cancelVideoRecording()
                    },
                    onSwitchCamera: {
                        viewModel.switchVideoCamera()
                    },
                    onSend: {
                        viewModel.stopVideoRecording()
                    }
                )
                .zIndex(1000)
                .ignoresSafeArea()
            }

            // Overlay для записи голосового сообщения на полный экран
            if viewModel.isRecordingVoice {
                VoiceRecordOverlayView(
                    duration: viewModel.voiceRecordingDuration,
                    audioLevel: viewModel.voiceAudioLevel,
                    isCanceling: viewModel.isCancelingVoice,
                    onCancel: {
                        viewModel.cancelVoiceRecording()
                    }
                )
                .zIndex(1000)
                .ignoresSafeArea()
            }
        }
        .appBackground()
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
        .navigationTitle(viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(viewModel.displayName)
                        .font(.headline)
                    if !viewModel.typingUsers.isEmpty {
                        Text("Печатает...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ChatSettingsView(chatId: chatId)
        }
        .sheet(isPresented: $viewModel.showStickerPicker) {
            StickerPickerView { stickerUrl in
                viewModel.sendSticker(stickerUrl: stickerUrl, packId: "")
            }
            .presentationDetents([.height(300)])
        }
        .onAppear {
            viewModel.loadChat(chatId: chatId)
            // Инициализируем фон при появлении
            chatBackgroundUrl = viewModel.chat?.backgroundUrl
        }
        .onChange(of: viewModel.chat?.backgroundUrl) { _, newValue in
            chatBackgroundUrl = newValue
            print("💬 ChatView: Background URL updated: \(newValue ?? "nil")")
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatBackgroundUpdated)) {
            notification in
            if let updatedChatId = notification.userInfo?["chatId"] as? String,
                updatedChatId == chatId
            {
                // Перезагружаем чат для получения обновленного фона
                viewModel.loadChat(chatId: chatId)
            }
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

// MARK: - Modern Scroll View (iOS 17+ APIs)
private struct ChatMessagesScrollView: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMoreMessages: Bool
    let currentUserId: String?
    let onLoadMore: () -> Void
    let onDeleteMessage: ((String) -> Void)?
    let findMessage: (String) -> ChatMessage?
    let onReply: (ChatMessage) -> Void
    let onReaction: (String, String) -> Void  // messageId, emoji

    @State private var scrollMetrics = ChatScrollMetrics.zero
    @State private var didPerformInitialScroll = false
    @State private var pendingHistoryAnchor: String?
    @State private var shouldStickToBottom = true
    @State private var isRestoringHistoryPosition = false
    @State private var historyLoadUnlocked = false
    @State private var previousMessages: [ChatMessage] = []
    @State private var didSnapshotMessages = false

    var body: some View {
        GeometryReader { containerGeo in
            SwiftUI.ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 8, pinnedViews: []) {
                        if isLoading && messages.isEmpty {
                            ProgressView()
                                .padding()
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId,
                                replyingToMessage: message.replyToId.flatMap(findMessage),
                                onReply: {
                                    onReply(message)
                                },
                                onReaction: { emoji in
                                    onReaction(message.id, emoji)
                                },
                                contextMenuBuilder: {
                                    if message.senderId == currentUserId,
                                        let onDelete = onDeleteMessage
                                    {
                                        return AnyView(
                                            Button(role: .destructive) {
                                                onDelete(message.id)
                                            } label: {
                                                Label("Удалить", systemImage: "trash")
                                            }
                                        )
                                    } else {
                                        return nil
                                    }
                                }
                            )
                            .id(message.id)
                            .onAppear {
                                // Принудительная загрузка медиа при появлении в viewport
                                // Это помогает загружать изображения при скролле
                            }
                        }

                        if isLoadingMore {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Загружаем историю…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear.preference(
                                key: ChatScrollMetricsKey.self,
                                value: ChatScrollMetrics(
                                    offset: contentGeo.frame(in: .named("chatScroll")).minY,
                                    contentHeight: contentGeo.size.height,
                                    containerHeight: containerGeo.size.height
                                )
                            )
                        }
                    )
                }
                .coordinateSpace(name: "chatScroll")
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .onPreferenceChange(ChatScrollMetricsKey.self) { metrics in
                    scrollMetrics = metrics
                    handleScrollMetricsChange(metrics, proxy: proxy)
                }
                .onChange(of: messages.count, initial: true) { _, _ in
                    guard didSnapshotMessages else {
                        previousMessages = messages
                        didSnapshotMessages = true
                        return
                    }
                    handleMessagesChange(
                        oldValue: previousMessages, newValue: messages, proxy: proxy)
                    previousMessages = messages
                }
                .onChange(of: isLoadingMore) { _, newValue in
                    if !newValue {
                        restoreHistoryPositionIfNeeded(proxy: proxy)
                    }
                }
            }
        }
    }

    private func triggerHistoryLoad() {
        guard pendingHistoryAnchor == nil else { return }
        pendingHistoryAnchor = messages.first?.id
        onLoadMore()
    }

    private func restoreHistoryPositionIfNeeded(proxy: ScrollViewProxy) {
        guard let anchor = pendingHistoryAnchor else { return }
        guard messages.contains(where: { $0.id == anchor }) else {
            pendingHistoryAnchor = nil
            return
        }

        pendingHistoryAnchor = nil
        isRestoringHistoryPosition = true
        DispatchQueue.main.async {
            proxy.scrollTo(anchor, anchor: .top)
            DispatchQueue.main.async {
                isRestoringHistoryPosition = false
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = messages.last?.id else { return }
        func performScroll(_ animated: Bool) {
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }

        DispatchQueue.main.async {
            performScroll(animated)

            // Повторяем скролл немного позже, чтобы учесть изменение высоты
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                performScroll(false)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    performScroll(false)
                }
            }
        }
    }

    private func handleScrollMetricsChange(_ metrics: ChatScrollMetrics, proxy: ScrollViewProxy) {
        shouldStickToBottom = metrics.isNearBottom

        if didPerformInitialScroll && metrics.isNearBottom && !historyLoadUnlocked {
            historyLoadUnlocked = true
        }

        if metrics.isNearTop,
            hasMoreMessages,
            !isLoading,
            !isLoadingMore,
            !isRestoringHistoryPosition,
            historyLoadUnlocked
        {
            triggerHistoryLoad()
        }
    }

    private func handleMessagesChange(
        oldValue: [ChatMessage],
        newValue: [ChatMessage],
        proxy: ScrollViewProxy
    ) {
        guard !newValue.isEmpty else { return }

        if !didPerformInitialScroll {
            didPerformInitialScroll = true
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        if pendingHistoryAnchor != nil {
            // Ждем восстановления позиции после загрузки истории
            return
        }

        guard let lastMessage = newValue.last else { return }

        let isNewMessageAppended =
            oldValue.last?.id != lastMessage.id
            || newValue.count > oldValue.count

        guard isNewMessageAppended else { return }

        let isOwnMessage = lastMessage.senderId == currentUserId

        if shouldStickToBottom || isOwnMessage {
            scrollToBottom(proxy: proxy, animated: didPerformInitialScroll)
        }
    }
}

// MARK: - Scroll Metrics Helpers
private struct ChatScrollMetrics: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat

    static let zero = ChatScrollMetrics(offset: 0, contentHeight: 1, containerHeight: 1)

    var distanceFromTop: CGFloat {
        max(0, -offset)
    }

    var distanceFromBottom: CGFloat {
        max(0, (contentHeight + offset) - containerHeight)
    }

    var isNearTop: Bool {
        distanceFromTop < 100
    }

    var isNearBottom: Bool {
        distanceFromBottom < 150
    }
}

private struct ChatScrollMetricsKey: PreferenceKey {
    static var defaultValue: ChatScrollMetrics = .init(
        offset: 0, contentHeight: 0, containerHeight: 0)

    static func reduce(value: inout ChatScrollMetrics, nextValue: () -> ChatScrollMetrics) {
        value = nextValue()
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
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
    }

    // MARK: - Messages View
    private var messagesView: some View {
        ChatMessagesScrollView(
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
            },
            findMessage: { id in
                viewModel.findMessage(by: id)
            },
            onReply: { message in
                viewModel.setReplyingToMessage(message)
            },
            onReaction: { messageId, emoji in
                viewModel.handleReaction(messageId: messageId, emoji: emoji)
            }
        )
    }

    // MARK: - Helper Methods
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Message Input View
    private var messageInputView: some View {
        VStack(spacing: 8) {
            // Бар ответа на сообщение
            if let replyingTo = viewModel.replyingToMessage {
                ReplyBarView(
                    replyingToMessage: replyingTo,
                    onClose: {
                        viewModel.clearReplyingToMessage()
                    }
                )
            }

            // Превью выбранных вложений
            if !viewModel.selectedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.selectedAttachments.enumerated()), id: \.element.id)
                        { index, attachment in
                            AttachmentPreviewView(attachment: attachment) {
                                viewModel.removeAttachment(at: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
            }

            HStack(spacing: 12) {
                // Кнопка выбора файла
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    Image(systemName: "paperclip")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.isSending || viewModel.selectedAttachments.count >= 10)
                .onChange(of: selectedPhotoItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task {
                        for item in newItems {
                            // Пробуем загрузить как изображение
                            if let data = try? await item.loadTransferable(type: Data.self),
                                let image = UIImage(data: data)
                            {
                                viewModel.addAttachment(ChatAttachment(image: image))
                                continue
                            }

                            // Если не изображение, пробуем загрузить как видео через URL
                            if let videoTransferable = await
                                (try? item.loadTransferable(type: VideoFileTransferable.self))
                            {
                                let tempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension("mp4")

                                do {
                                    // Копируем файл во временную директорию
                                    try FileManager.default.copyItem(
                                        at: videoTransferable.url, to: tempURL)
                                    let thumbnail = await generateThumbnail(for: tempURL)
                                    viewModel.addAttachment(
                                        ChatAttachment(videoURL: tempURL, thumbnail: thumbnail))
                                } catch {
                                    print("❌ Failed to save video: \(error)")
                                }
                                continue
                            }

                            // Альтернативный способ для видео - через Movie
                            if let movie = await (try? item.loadTransferable(type: Movie.self)) {
                                let tempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension("mp4")

                                do {
                                    // Копируем файл во временную директорию
                                    try FileManager.default.copyItem(at: movie.url, to: tempURL)
                                    let thumbnail = await generateThumbnail(for: tempURL)
                                    viewModel.addAttachment(
                                        ChatAttachment(videoURL: tempURL, thumbnail: thumbnail))
                                } catch {
                                    print("❌ Failed to save video: \(error)")
                                }
                            }
                        }
                        // Сбрасываем после обработки
                        selectedPhotoItems = []
                    }
                }

                // Кнопка выбора стикера
                Button(action: {
                    viewModel.showStickerPicker.toggle()
                }) {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.isSending)

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

                // Кнопки записи видео/голоса
                if !viewModel.messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty || !viewModel.selectedAttachments.isEmpty
                {
                    // Если есть текст или вложения - кнопка отправки
                    ZStack {
                        if viewModel.isUploadingAttachments {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 32, height: 32)
                        } else {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(viewModel.isSending ? .gray : .accentColor)
                            }
                            .disabled(viewModel.isSending)
                        }
                    }
                    .frame(width: 32, height: 32)
                } else {
                    // Если нет текста - кнопка переключения между режимами записи видео и голоса
                    RecordModeToggleButton(viewModel: viewModel)
                }
            }
        }
        .padding()
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }

    // MARK: - Record Mode Toggle Button
    private struct RecordModeToggleButton: View {
        @ObservedObject var viewModel: ChatViewModel
        @State private var isVideoMode: Bool = true  // По умолчанию режим видео
        @State private var isPressed = false
        @State private var dragOffset: CGSize = .zero
        @State private var hasStartedRecording = false  // Локальное отслеживание начала записи
        @State private var longPressCompleted = false  // Для отслеживания LongPress в аудио режиме
        @State private var videoRecordingTimerTask: Task<Void, Never>? = nil  // Задача таймера для начала записи видео

        var body: some View {
            Button(action: {
                // Переключаем режим только если не идет запись
                if !viewModel.isRecordingVideo && !viewModel.isRecordingVoice {
                    isVideoMode.toggle()
                }
            }) {
                Image(systemName: isVideoMode ? "video.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .onChange(of: viewModel.isRecordingVideo) { _, isRecording in
                if isRecording {
                    // При начале записи сразу показываем панель управления
                    viewModel.showVideoControls = true
                    viewModel.isCancelingVideo = false
                } else {
                    // Сбрасываем флаг когда запись останавливается
                    hasStartedRecording = false
                    isPressed = false
                    dragOffset = .zero
                    // Отменяем таймер, если он был запущен
                    videoRecordingTimerTask?.cancel()
                    videoRecordingTimerTask = nil
                }
            }
            .onChange(of: viewModel.isRecordingVoice) { _, isRecording in
                // Сбрасываем флаг когда запись голоса останавливается
                if !isRecording {
                    hasStartedRecording = false
                    isPressed = false
                    dragOffset = .zero
                    longPressCompleted = false
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.1)
                    .onEnded { _ in
                        // Для аудио режима - начинаем запись
                        if !isVideoMode && !viewModel.isRecordingVoice {
                            longPressCompleted = true
                            viewModel.startVoiceRecording()
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragOffset = value.translation

                        if isVideoMode {
                            // Режим видео
                            // Начинаем запись только если есть движение или прошло небольшое время
                            let horizontalDistance = abs(value.translation.width)
                            let verticalDistance = abs(value.translation.height)
                            let totalDistance = sqrt(
                                pow(value.translation.width, 2) + pow(value.translation.height, 2))

                            // Если еще не начали запись
                            if !isPressed && !hasStartedRecording {
                                // Если есть движение (> 5px) - начинаем сразу
                                if totalDistance > 5 {
                                    // Отменяем таймер, если он был запущен
                                    videoRecordingTimerTask?.cancel()
                                    videoRecordingTimerTask = nil

                                    isPressed = true
                                    hasStartedRecording = true
                                    // Сразу показываем панель управления
                                    viewModel.showVideoControls = true
                                    viewModel.isCancelingVideo = false
                                    viewModel.startVideoRecording()
                                } else {
                                    // Если нет движения - запускаем таймер для начала записи через 0.3 секунды
                                    if videoRecordingTimerTask == nil {
                                        videoRecordingTimerTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 секунды

                                            // Проверяем на главном потоке, что задача не была отменена и запись еще не началась
                                            await MainActor.run {
                                                if !Task.isCancelled && !hasStartedRecording
                                                    && !viewModel.isRecordingVideo
                                                {
                                                    isPressed = true
                                                    hasStartedRecording = true
                                                    // Сразу показываем панель управления
                                                    viewModel.showVideoControls = true
                                                    viewModel.isCancelingVideo = false
                                                    viewModel.startVideoRecording()
                                                }

                                                // Очищаем задачу после выполнения
                                                videoRecordingTimerTask = nil
                                            }
                                        }
                                    }
                                }
                            }

                            // Определяем направление свайпа независимо от состояния isRecordingVideo
                            // (так как запись может начаться асинхронно)

                            // Свайп влево (отрицательный width) - отмена записи
                            if value.translation.width < -50
                                && horizontalDistance > verticalDistance
                            {
                                viewModel.isCancelingVideo = true
                                viewModel.showVideoControls = false
                            } else {
                                // Если не свайп влево - показываем панель управления (она всегда видна при записи)
                                if viewModel.isRecordingVideo {
                                    viewModel.isCancelingVideo = false
                                    viewModel.showVideoControls = true
                                }
                            }
                        } else {
                            // Режим аудио
                            // Если свайп влево (отрицательный width) больше 50px - показываем индикатор отмены
                            if viewModel.isRecordingVoice {
                                let horizontalDistance = abs(value.translation.width)
                                let verticalDistance = abs(value.translation.height)
                                viewModel.isCancelingVoice =
                                    value.translation.width < -50
                                    && horizontalDistance > verticalDistance
                            }
                        }
                    }
                    .onEnded { value in
                        if isVideoMode {
                            // Режим видео
                            let horizontalDistance = abs(value.translation.width)
                            let verticalDistance = abs(value.translation.height)

                            // Если был свайп влево - отменяем запись
                            if value.translation.width < -50
                                && horizontalDistance > verticalDistance
                            {
                                // Отменяем таймер, если он был запущен
                                videoRecordingTimerTask?.cancel()
                                videoRecordingTimerTask = nil

                                if hasStartedRecording {
                                    viewModel.cancelVideoRecording()
                                }
                                isPressed = false
                                hasStartedRecording = false
                                dragOffset = .zero
                                viewModel.showVideoControls = false
                                viewModel.isCancelingVideo = false
                                return
                            }

                            // Отменяем таймер, если он был запущен
                            videoRecordingTimerTask?.cancel()
                            videoRecordingTimerTask = nil

                            // Если запись идет - панель управления остается видимой, запись продолжается
                            if viewModel.isRecordingVideo {
                                viewModel.showVideoControls = true
                                viewModel.isCancelingVideo = false
                                // Запись продолжается, не отправляем
                                isPressed = false
                                dragOffset = .zero
                                return
                            }

                            // Если запись не началась - отправляем, если была начата
                            if hasStartedRecording {
                                viewModel.stopVideoRecording()
                            }
                            hasStartedRecording = false
                            isPressed = false
                            dragOffset = .zero
                            viewModel.isCancelingVideo = false
                        } else {
                            // Режим аудио
                            if viewModel.isRecordingVoice {
                                let horizontalDistance = abs(value.translation.width)
                                let verticalDistance = abs(value.translation.height)

                                // Если свайп влево больше 50px - отмена
                                if value.translation.width < -50
                                    && horizontalDistance > verticalDistance
                                {
                                    viewModel.cancelVoiceRecording()
                                } else {
                                    // Иначе отправка
                                    viewModel.stopVoiceRecording()
                                }
                            }
                            dragOffset = .zero
                            viewModel.isCancelingVoice = false
                            longPressCompleted = false
                        }
                    }
            )
        }
    }

    // MARK: - Attachment Preview View
    private struct AttachmentPreviewView: View {
        let attachment: ChatAttachment
        let onRemove: () -> Void

        var body: some View {
            ZStack(alignment: .topTrailing) {
                if let image = attachment.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if attachment.videoURL != nil {
                    ZStack {
                        if let thumbnail = attachment.thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                        }

                        // Иконка видео
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack {
                                Image(systemName: "doc.fill")
                                    .font(.title2)
                                Text(attachment.fileName ?? "Файл")
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        )
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .offset(x: 4, y: -4)
            }
        }
    }

    // MARK: - Reply Bar View
    private struct ReplyBarView: View {
        let replyingToMessage: ChatMessage
        let onClose: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                // Вертикальная линия слева
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .frame(height: 20)
                    .cornerRadius(1.5)

                HStack(spacing: 6) {
                    Text("Ответ на")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(replyingToMessage.sender?.displayName ?? "Пользователь")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                if !replyingToMessage.content.isEmpty && replyingToMessage.messageType == .text {
                    Text(replyingToMessage.content)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                } else if !replyingToMessage.attachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: getAttachmentIcon())
                            .font(.caption2)
                        Text(getAttachmentText())
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)

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

    // MARK: - Helper Functions

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
    }

    private func generateThumbnail(for videoURL: URL) async -> UIImage? {
        // Проверяем кэш сначала
        if let cachedThumbnail = await VideoThumbnailCache.shared.getThumbnail(for: videoURL) {
            return cachedThumbnail
        }

        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        // Уменьшаем размер превью для лучшей производительности
        imageGenerator.maximumSize = CGSize(width: 400, height: 400)

        do {
            let cgImage = try await imageGenerator.image(at: CMTime.zero).image
            let thumbnail = UIImage(cgImage: cgImage)

            // Сохраняем в кэш
            await VideoThumbnailCache.shared.setThumbnail(thumbnail, for: videoURL)

            return thumbnail
        } catch {
            print("❌ Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Video Transferable Types

struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let url = received.file
            return VideoFileTransferable(url: url)
        }
    }
}

struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let url = received.file
            return Movie(url: url)
        }
    }
}
