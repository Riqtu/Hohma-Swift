//
//  hohmaApp.swift
//  hohma
//
//  Created by Artem Vydro on 17.07.2025.
//

import AVFoundation
import Inject
import SwiftUI

@main
struct hohmaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
            InjectConfiguration.animation = .interactiveSpring()
        #endif

        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                print("❌ Ошибка настройки аудиосессии в приложении: \(error)")
            }
        #elseif os(macOS)
            // На macOS аудиосессия настраивается автоматически
            // Видео будет воспроизводиться без звука (isMuted = true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Глобальный фон для всего приложения
                AppBackground(useVideoBackground: false)
                    .ignoresSafeArea()

                RootView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Приложение стало активным - возобновляем видео
                VideoPlayerManager.shared.resumeAllPlayers()
            case .inactive:
                // Приложение стало неактивным - приостанавливаем видео
                VideoPlayerManager.shared.pauseAllPlayers()
            case .background:
                // Приложение в фоне - приостанавливаем видео
                VideoPlayerManager.shared.pauseAllPlayers()
            @unknown default:
                break
            }
        }
    }
}
