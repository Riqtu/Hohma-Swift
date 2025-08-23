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
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    /// Применяет фон к экрану (для отдельных экранов)
    func screenBackground() -> some View {
        self.background(
            AppBackground(useVideoBackground: false)
                .ignoresSafeArea()
        )
    }
}
