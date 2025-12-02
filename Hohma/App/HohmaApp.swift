//
//  hohmaApp.swift
//  hohma
//
//  Created by Artem Vydro on 17.07.2025.
//

import AVFoundation
import Inject
import SwiftUI
import UserNotifications

@main
struct hohmaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let videoManager = VideoPlayerManager.shared
    @StateObject private var settingsViewModel = SettingsViewModel()
    private let pushNotificationService = PushNotificationService.shared

    // AppDelegate для обработки push-уведомлений
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
            InjectConfiguration.animation = .interactiveSpring()
        #endif

        setupAudioSession()
        preloadCommonVideos()
        setupOrientation()
        setupPushNotifications()
        
        // Инициализируем менеджер кэша
        _ = CacheManagerService.shared
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

    private func preloadCommonVideos() {
        // Предварительно загружаем часто используемые видео
        videoManager.preloadVideo(resourceName: "background")
        videoManager.preloadVideo(resourceName: "affirmation")
        videoManager.preloadVideo(resourceName: "movie")
        videoManager.preloadVideo(resourceName: "persons")
    }

    private func setupOrientation() {
        #if os(iOS)
            // Блокируем поворот экрана для iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                UIDevice.current.setValue(
                    UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
        #endif
    }

    private func setupPushNotifications() {
        #if os(iOS)
            // Настраиваем делегат для push-уведомлений
            UNUserNotificationCenter.current().delegate = pushNotificationService

            // Настраиваем категории уведомлений
            pushNotificationService.setupNotificationCategories()

            // Запрашиваем разрешение на уведомления
            Task {
                await pushNotificationService.requestAuthorization()
            }
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
            .tint(Color("AccentColor"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Приложение стало активным - возобновляем видео и применяем сохраненную тему
            videoManager.resumeAllPlayers()
            settingsViewModel.applySavedTheme()

            // Очищаем badge при активации приложения
            #if os(iOS)
                pushNotificationService.clearBadge()
            #endif

        case .inactive:
            // Приложение стало неактивным - приостанавливаем видео
            videoManager.pauseAllPlayers()
        case .background:
            // Приложение в фоне - приостанавливаем видео
            videoManager.pauseAllPlayers()
        @unknown default:
            break
        }
    }
}
