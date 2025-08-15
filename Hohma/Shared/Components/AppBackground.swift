//
//  AppBackground.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AVFoundation
import Inject
import SwiftUI

struct AppBackground: View {
    @ObserveInjection var inject
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var backgroundPlayer: AVPlayer?
    @State private var isPlayerReady: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    // Настройки фона
    let useVideoBackground: Bool
    let videoName: String

    init(useVideoBackground: Bool = false, videoName: String = "background") {
        self.useVideoBackground = useVideoBackground
        self.videoName = videoName
    }

    var body: some View {
        ZStack {
            if useVideoBackground, let player = backgroundPlayer, isPlayerReady {
                // Видео фон
                VideoBackgroundView(player: player)
                    .ignoresSafeArea()

                // Полупрозрачный оверлей для лучшей читаемости
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            } else if useVideoBackground {
                // Показываем градиент пока видео загружается
                AnimatedGradientBackground()
                    .ignoresSafeArea()
            } else {
                // Анимированный градиентный фон
                AnimatedGradientBackground()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if useVideoBackground {
                setupVideoBackground()
            }
        }
        .onDisappear {
            cleanupVideoBackground()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .enableInjection()
    }

    private func setupVideoBackground() {
        // Предварительно загружаем видео
        videoManager.preloadVideo(resourceName: videoName)

        // Получаем плеер
        backgroundPlayer = videoManager.player(resourceName: videoName)

        // Настраиваем observer для готовности
        if let player = backgroundPlayer {
            setupPlayerObserver(player)
        }
    }

    private func setupPlayerObserver(_ player: AVPlayer) {
        // Observer для отслеживания готовности плеера
        _ = player.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                self.isPlayerReady = item.status == .readyToPlay
                if self.isPlayerReady {
                    player.play()
                }
            }
        }
    }

    private func cleanupVideoBackground() {
        backgroundPlayer?.pause()
        backgroundPlayer = nil
        isPlayerReady = false
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if useVideoBackground && isPlayerReady {
                backgroundPlayer?.play()
            }
        case .inactive, .background:
            backgroundPlayer?.pause()
        @unknown default:
            break
        }
    }
}

// Расширение для удобного использования
extension View {
    func appBackground(useVideo: Bool = false, videoName: String = "background") -> some View {
        ZStack {
            AppBackground(useVideoBackground: useVideo, videoName: videoName)
            self
        }
    }
}

#Preview {
    VStack {
        Text("Тестовый контент")
            .font(.title)
            .foregroundColor(.white)
    }
    .appBackground(useVideo: false)
}
