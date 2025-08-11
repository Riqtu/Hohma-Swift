//
//  AppBackground.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AVFoundation
import SwiftUI

struct AppBackground: View {
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var backgroundPlayer: AVPlayer?
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
            if useVideoBackground, let player = backgroundPlayer {
                // Видео фон
                VideoBackgroundView(player: player)
                    .ignoresSafeArea()

                // Полупрозрачный оверлей для лучшей читаемости
                Color.black.opacity(0.3)
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
            backgroundPlayer?.pause()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if useVideoBackground {
                    backgroundPlayer?.play()
                }
            case .inactive, .background:
                backgroundPlayer?.pause()
            @unknown default:
                break
            }
        }
    }

    private func setupVideoBackground() {
        backgroundPlayer = videoManager.player(resourceName: videoName)
        backgroundPlayer?.play()
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
