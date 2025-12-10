//
//  ViewExtensions.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI

extension View {
    /// Применяет стандартный фон приложения
    func withAppBackground() -> some View {
        self.background(
            AppBackground(useVideoBackground: false)
                .ignoresSafeArea()
        )
    }

    /// Автоматически применяет фон, если он еще не установлен
    func withAutoBackground() -> some View {
        self.background(
            AppBackground(useVideoBackground: false)
                .ignoresSafeArea()
        )
    }

    /// Применяет видео фон
    func withVideoBackground(videoName: String = "background") -> some View {
        self.background(
            AppBackground(useVideoBackground: true, videoName: videoName)
                .ignoresSafeArea()
        )
    }

    /// Применяет стандартную карточку с фоном
    func cardStyle() -> some View {
        self.background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Применяет фон к экрану (для отдельных экранов)
    func screenBackground() -> some View {
        self.background(
            AppBackground(useVideoBackground: false)
                .ignoresSafeArea()
        )
    }
}

// MARK: - NotificationCenter Extensions
extension Notification.Name {
    static let raceUpdated = Notification.Name("raceUpdated")
    static let shareRace = Notification.Name("shareRace")
    static let shareMovieBattle = Notification.Name("shareMovieBattle")
    static let shareWheel = Notification.Name("shareWheel")
}
