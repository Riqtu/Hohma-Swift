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
    @State private var isVideoReady: Bool = false
    @State private var playerObserver: NSKeyValueObservation?
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false

    let title: String
    let description: String
    let imageName: String?  // имя в Assets или URL
    let videoName: String?  // имя видео в Assets
    let player: AVPlayer?  // <-- сюда передавай готовый
    let action: (() -> Void)?

    var body: some View {
        Button(action: {
            print("🎴 CardView: Нажатие на карточку '\(title)'")
            action?()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Показываем либо видео, либо картинку, либо ничего
                Group {
                    if let player = player ?? videoPlayer, isVideoReady {
                        VideoBackgroundView(player: player)
                    } else if let imageName, !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()

                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                Text(description)
                    .font(.body)
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
            setupVideoIfNeeded()
        }
        .onDisappear {
            cleanupVideo()
        }
        .enableInjection()
    }

    private func setupVideoIfNeeded() {
        print("🎴 CardView: Настройка видео для \(title)")

        // Если уже есть готовый плеер, используем его
        if let player = player {
            print("🎴 CardView: Используем готовый плеер")
            setupPlayerObserver(player)
            return
        }

        // Если есть имя видео, загружаем его
        if let videoName = videoName, !videoName.isEmpty {
            print("🎴 CardView: Загружаем видео \(videoName)")
            videoPlayer = videoManager.player(resourceName: videoName)
            if let player = videoPlayer {
                setupPlayerObserver(player)
            }
        }
    }

    private func setupPlayerObserver(_ player: AVPlayer) {
        // Очищаем предыдущий observer
        playerObserver?.invalidate()

        playerObserver = player.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                print("🎴 CardView: Статус плеера для \(self.title): \(item.status.rawValue)")
                self.isVideoReady = item.status == .readyToPlay
                if self.isVideoReady {
                    print("🎴 CardView: Видео готово для \(self.title)")
                }
            }
        }

        // Проверяем текущий статус
        if player.currentItem?.status == .readyToPlay {
            print("🎴 CardView: Плеер уже готов для \(title)")
            self.isVideoReady = true
        }
    }

    private func cleanupVideo() {
        print("🎴 CardView: Очистка видео для \(title)")
        playerObserver?.invalidate()
        playerObserver = nil

        if player == nil {  // Только если это не внешний плеер
            videoPlayer?.pause()
            videoPlayer = nil
        }
        isVideoReady = false
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
            print("Карточка нажата")
        }
    )
}
