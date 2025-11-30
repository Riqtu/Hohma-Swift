//
//  SkeletonLoader.swift
//  Hohma
//
//  Created by Assistant
//

import Inject
import SwiftUI

/// Универсальный компонент для отображения skeleton loader с анимацией shimmer эффекта
struct SkeletonLoader: View {
    @ObserveInjection var inject
    @State private var isAnimating = false

    /// Базовый цвет фона
    var baseColor: Color = .gray.opacity(0.3)

    /// Цвет градиента shimmer эффекта
    var shimmerColor: Color = .gray.opacity(0.1)

    /// Скорость анимации (в секундах)
    var animationDuration: Double = 1.5

    /// Ширина градиента относительно ширины view (0.0 - 1.0)
    var gradientWidth: CGFloat = 0.6

    /// Включить/выключить анимацию
    var isAnimated: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Базовый цвет
                baseColor

                // Анимированный градиент shimmer
                if isAnimated {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            shimmerColor,
                            Color.clear,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * gradientWidth)
                    .offset(
                        x: isAnimating ? geometry.size.width : -geometry.size.width * gradientWidth)
                }
            }
        }
        .onAppear {
            if isAnimated {
                withAnimation(
                    Animation.linear(duration: animationDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
        }
        .enableInjection()
    }
}

// MARK: - Convenience Initializers

extension SkeletonLoader {
    /// Создает skeleton loader с кастомными параметрами
    init(
        baseColor: Color = .gray.opacity(0.2),
        shimmerColor: Color = .white.opacity(0.3),
        duration: Double = 1.5,
        gradientWidth: CGFloat = 0.6,
        isAnimated: Bool = true
    ) {
        self.baseColor = baseColor
        self.shimmerColor = shimmerColor
        self.animationDuration = duration
        self.gradientWidth = gradientWidth
        self.isAnimated = isAnimated
    }

    /// Создает skeleton loader с темной темой
    static func dark(
        duration: Double = 1.5,
        isAnimated: Bool = true
    ) -> SkeletonLoader {
        SkeletonLoader(
            baseColor: .gray.opacity(0.3),
            shimmerColor: .white.opacity(0.2),
            duration: duration,
            isAnimated: isAnimated
        )
    }

    /// Создает skeleton loader со светлой темой
    static func light(
        duration: Double = 1.5,
        isAnimated: Bool = true
    ) -> SkeletonLoader {
        SkeletonLoader(
            baseColor: .gray.opacity(0.15),
            shimmerColor: .white.opacity(0.4),
            duration: duration,
            isAnimated: isAnimated
        )
    }

    /// Создает skeleton loader с акцентным цветом
    static func accent(
        accentColor: Color,
        duration: Double = 1.5,
        isAnimated: Bool = true
    ) -> SkeletonLoader {
        SkeletonLoader(
            baseColor: accentColor.opacity(0.2),
            shimmerColor: accentColor.opacity(0.5),
            duration: duration,
            isAnimated: isAnimated
        )
    }
}
