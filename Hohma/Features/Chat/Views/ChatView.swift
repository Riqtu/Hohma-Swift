//
//  ChatView.swift
//  Hohma
//
//  Created by Artem Vydro on 30.10.2025.
//

import Inject
import PhotosUI
import SwiftUI
import UIKit

struct ChatView: View {
    @ObserveInjection var inject
    let chatId: String
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageToDelete: String? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
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
        }
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
    let findMessage: (String) -> ChatMessage?
    let onReply: (ChatMessage) -> Void

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
                            isCurrentUser: message.senderId == currentUserId,
                            replyingToMessage: message.replyToId != nil
                                ? findMessage(message.replyToId!) : nil,
                            onReply: {
                                onReply(message)
                            }
                        )
                        .id(message.id)
                        .contentShape(Rectangle())  // Важно для правильной обработки тапов
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
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .id("bottom")

            }
            .coordinateSpace(name: "scroll")
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                // Одновременный жест для закрытия клавиатуры
                // Работает на пустых областях, не блокируя тапы на сообщения
                TapGesture()
                    .onEnded { _ in
                        hideKeyboard()
                    }
            )
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            },
            findMessage: { id in
                viewModel.findMessage(by: id)
            },
            onReply: { message in
                viewModel.setReplyingToMessage(message)
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
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Image(systemName: "paperclip")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.isSending || viewModel.selectedAttachments.count >= 10)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem = newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                            let image = UIImage(data: data)
                        {
                            await MainActor.run {
                                viewModel.addAttachment(ChatAttachment(image: image))
                                selectedPhotoItem = nil  // Сбрасываем после обработки
                            }
                        }
                    }
                }

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
}
