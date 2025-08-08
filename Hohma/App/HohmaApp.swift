//
//  hohmaApp.swift
//  hohma
//
//  Created by Artem Vydro on 17.07.2025.
//

import Inject
import SwiftUI

@main
struct hohmaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
            InjectConfiguration.animation = .interactiveSpring()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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
