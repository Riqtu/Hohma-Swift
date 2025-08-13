import AVFoundation
import Inject
import SwiftUI

struct HomeHeader: View {
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var player: AVPlayer?
    @State private var isVideoReady: Bool = false
    @State private var playerObserver: NSKeyValueObservation?
    @Environment(\.scenePhase) private var scenePhase
    @ObserveInjection var inject

    var body: some View {
        ZStack {
            if let player = player, isVideoReady {
                VideoBackgroundView(player: player)
                    .frame(height: 250)
                    .clipped()
            } else {
                // Показываем градиент пока видео загружается
                AnimatedGradientBackground()
                    .frame(height: 250)
                    .clipped()
            }

            // Полупрозрачный оверлей
            Color.black.opacity(0.7)
                .frame(height: 250)

            VStack(spacing: 10) {
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 24))
                    .foregroundColor(.white)

                Text("Приложение для своих.\nВсё, что важно — в одном месте.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .frame(height: 250)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .enableInjection()
    }

    private func setupPlayer() {
        print("🏠 HomeHeader: Настройка плеера")

        // Предварительно загружаем видео
        videoManager.preloadVideo(resourceName: "background")

        // Получаем плеер
        player = videoManager.player(resourceName: "background")

        // Настраиваем observer для готовности
        if let player = player {
            setupPlayerObserver(player)
        }
    }

    private func setupPlayerObserver(_ player: AVPlayer) {
        // Очищаем предыдущий observer
        playerObserver?.invalidate()

        playerObserver = player.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                print("🏠 HomeHeader: Статус плеера: \(item.status.rawValue)")
                self.isVideoReady = item.status == .readyToPlay
                if self.isVideoReady {
                    print("🏠 HomeHeader: Плеер готов, запускаем воспроизведение")
                    player.play()
                }
            }
        }

        // Проверяем текущий статус
        if player.currentItem?.status == .readyToPlay {
            print("🏠 HomeHeader: Плеер уже готов")
            self.isVideoReady = true
            player.play()
        }
    }

    private func cleanupPlayer() {
        print("🏠 HomeHeader: Очистка плеера")
        playerObserver?.invalidate()
        playerObserver = nil
        player?.pause()
        player = nil
        isVideoReady = false
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if isVideoReady {
                player?.play()
            }
        case .inactive, .background:
            player?.pause()
        @unknown default:
            break
        }
    }
}

#Preview {
    HomeHeader()
}
