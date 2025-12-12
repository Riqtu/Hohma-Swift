import AVFoundation
import Inject
//
//  CardView.swift
//  Hohma
//
//  Created by Artem Vydro on 03.08.2025.
//
import SwiftUI

struct CardView: View {
    @ObserveInjection var inject
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var videoPlayer: AVPlayer?
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false
    @State private var isVideoVisible: Bool = true
    @Environment(\.scenePhase) private var scenePhase

    let title: String
    let description: String
    let imageName: String?  // имя в Assets или URL
    let videoName: String?  // имя видео в Assets
    let player: AVPlayer?  // готовый плеер из VideoPlayerManager
    let action: (() -> Void)?

    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Показываем либо видео, либо картинку
                Group {
                    if let player = player ?? videoPlayer {
                        VideoBackgroundView(player: player, isVisible: isVideoVisible)
                    } else if let imageName, !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()

                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .cardStyle()
            .frame(maxWidth: 380)
            .padding(.horizontal)
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .shadow(color: isHovered ? .primary.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(
            minimumDuration: 0, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {}
        )
        .accessibilityLabel("Карточка: \(title)")
        .accessibilityHint("Нажмите для перехода к \(title)")
        .onAppear {
            isVideoVisible = true
            setupVideoIfNeeded()
            resumeVideoPlayback()
        }
        // НЕ паузим при onDisappear - карточки должны играть пока видны
        // Управление через scenePhase для lifecycle приложения
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // При возврате в приложение возобновляем видео
                isVideoVisible = true
                // Используем async для гарантии что выполнится на следующем run loop
                DispatchQueue.main.async {
                    resumeVideoPlayback()
                }
            case .inactive, .background:
                // При уходе в фон останавливаем видео
                pauseVideoPlayback()
            @unknown default:
                break
            }
        }
        .enableInjection()
    }

    private func setupVideoIfNeeded() {
        // Если уже есть готовый плеер, используем его
        if player != nil {
            return
        }

        // Если есть имя видео, загружаем его
        if let videoName = videoName, !videoName.isEmpty {
            videoPlayer = videoManager.player(resourceName: videoName)
        }
    }

    private func resumeVideoPlayback() {
        guard let player = player ?? videoPlayer else { return }

        // Проверяем состояние плеера перед запуском
        let status = player.currentItem?.status ?? .unknown
        let timeControlStatus = player.timeControlStatus

        // Запускаем только если не играет и не ждет
        if timeControlStatus != .playing && timeControlStatus != .waitingToPlayAtSpecifiedRate {
            if status == .readyToPlay {
                // Готово - запускаем сразу
                player.play()
            } else {
                // Еще не готово - вызываем play(), чтобы запустилось когда будет готово
                // AVPlayer автоматически начнет воспроизведение при готовности
                player.play()
            }
        }
    }

    private func pauseVideoPlayback() {
        guard let player = player ?? videoPlayer else { return }

        // Паузим только если действительно играет
        if player.timeControlStatus == .playing {
            player.pause()
        }
    }
}

#Preview {
    CardView(
        title: "Заголовок карточки",
        description:
            "Тут может быть краткое описание, детали, и даже несколько строк текста. Всё как надо.",
        imageName: "testImage",
        videoName: "background",
        player: VideoPlayerManager.shared.player(resourceName: "background"),
        action: {
            AppLogger.shared.debug("Карточка нажата", category: .ui)
        }
    )
}
