//
//  AnimatedGradientBackground.swift
//  Hohma
//
//  Created by Artem Vydro on 04.08.2025.
//

import Inject
import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct AnimatedGradientBackground: View {
    @ObserveInjection var inject
    @Environment(\.colorScheme) private var colorScheme

    // Массив rgb для каждого цвета - серые оттенки в зависимости от темы
    var gradients: [[SIMD3<Double>]] {
        if colorScheme == .dark {
            // Темная тема - очень темные серые оттенки
            return [
                [SIMD3(0.05, 0.05, 0.06), SIMD3(0.08, 0.08, 0.09)],
                [SIMD3(0.07, 0.07, 0.08), SIMD3(0.10, 0.10, 0.11)],
                [SIMD3(0.04, 0.04, 0.05), SIMD3(0.09, 0.09, 0.10)],
                [SIMD3(0.06, 0.06, 0.07), SIMD3(0.11, 0.11, 0.12)],
            ]
        } else {
            // Светлая тема - светлосерые оттенки
            return [
                [SIMD3(0.95, 0.95, 0.96), SIMD3(0.97, 0.97, 0.98)],
                [SIMD3(0.93, 0.93, 0.94), SIMD3(0.96, 0.96, 0.97)],
                [SIMD3(0.94, 0.94, 0.95), SIMD3(0.98, 0.98, 0.99)],
                [SIMD3(0.96, 0.96, 0.97), SIMD3(0.92, 0.92, 0.93)],
            ]
        }
    }

    @State private var currentIndex = 0
    @State private var nextIndex = 1
    @State private var progress: CGFloat = 0.0

    let animationDuration: Double = 3

    var body: some View {
        let safeCurrentIndex = min(currentIndex, gradients.count - 1)
        let safeNextIndex = min(nextIndex, gradients.count - 1)

        LinearGradient(
            colors: interpolatedColors(
                from: gradients[safeCurrentIndex],
                to: gradients[safeNextIndex],
                progress: progress
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            animate()
        }
        .enableInjection()
    }

    func animate() {
        withAnimation(.linear(duration: animationDuration)) {
            progress = 1.0
        }
        Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: true) { _ in
            let gradientsCount = gradients.count
            guard gradientsCount > 0 else { return }

            currentIndex = nextIndex
            nextIndex = (nextIndex + 1) % gradientsCount

            // Дополнительная проверка безопасности
            currentIndex = min(currentIndex, gradientsCount - 1)
            nextIndex = min(nextIndex, gradientsCount - 1)

            progress = 0.0
            withAnimation(.linear(duration: animationDuration)) {
                progress = 1.0
            }
        }
    }

    func interpolatedColors(from: [SIMD3<Double>], to: [SIMD3<Double>], progress: CGFloat)
        -> [Color]
    {
        zip(from, to).map { (c1, c2) in
            Color(
                red: c1.x + (c2.x - c1.x) * Double(progress),
                green: c1.y + (c2.y - c1.y) * Double(progress),
                blue: c1.z + (c2.z - c1.z) * Double(progress)
            )
        }
    }
}
#if os(macOS)
    import AppKit
#endif

extension Color {
    fileprivate var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        #if os(macOS)
            if let cgColor = self.cgColor,
                let nsColor = NSColor(cgColor: cgColor)?.usingColorSpace(.deviceRGB)
                    ?? NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
            {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                return (red, green, blue)
            }
            return (1, 1, 1)
        #else
            // Для iOS/visionOS: безопасно разбираем Color(red:..., green:..., blue:...)
            // через приватные свойства с помощью Mirror (SwiftUI хак)
            let mirror = Mirror(reflecting: self)
            if let provider = mirror.children.first(where: { $0.label == "provider" })?.value {
                let providerMirror = Mirror(reflecting: provider)
                if let base = providerMirror.children.first(where: { $0.label == "base" })?.value {
                    let baseMirror = Mirror(reflecting: base)
                    if let red = baseMirror.children.first(where: { $0.label == "red" })?.value
                        as? Double,
                        let green = baseMirror.children.first(where: { $0.label == "green" })?.value
                            as? Double,
                        let blue = baseMirror.children.first(where: { $0.label == "blue" })?.value
                            as? Double
                    {
                        return (CGFloat(red), CGFloat(green), CGFloat(blue))
                    }
                }
            }
            return (1, 1, 1)
        #endif
    }
}
