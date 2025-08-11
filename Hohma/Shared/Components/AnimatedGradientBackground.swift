//
//  AnimatedGradientBackground.swift
//  Hohma
//
//  Created by Artem Vydro on 04.08.2025.
//

import SwiftUI
import Inject

struct AnimatedGradientBackground: View {
    @ObserveInjection var inject
    @Environment(\.colorScheme) private var colorScheme

    // Теперь массив rgb для каждого цвета
    var gradients: [[SIMD3<Double>]] {
        if colorScheme == .dark {
            return [
                [SIMD3(0.12, 0.12, 0.13), SIMD3(0.17, 0.17, 0.19)],
                [SIMD3(0.09, 0.09, 0.12), SIMD3(0.22, 0.22, 0.25)],
                [SIMD3(0.05, 0.05, 0.08), SIMD3(0.18, 0.18, 0.22)],
                [SIMD3(0.08, 0.08, 0.12), SIMD3(0.15, 0.15, 0.17)],
            ]
        } else {
            return [
                [SIMD3(0.93, 0.93, 0.95), SIMD3(1, 1, 1)],
                [SIMD3(0.85, 0.85, 0.89), SIMD3(0.95, 0.95, 0.97)],
                [SIMD3(0.82, 0.82, 0.85), SIMD3(0.99, 0.99, 0.99)],
                [SIMD3(0.90, 0.90, 0.94), SIMD3(0.97, 0.97, 1)],
            ]
        }
    }

    @State private var currentIndex = 0
    @State private var nextIndex = 1
    @State private var progress: CGFloat = 0.0

    let animationDuration: Double = 1

    var body: some View {
        LinearGradient(
            colors: interpolatedColors(
                from: gradients[currentIndex],
                to: gradients[nextIndex],
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
            currentIndex = nextIndex
            nextIndex = (nextIndex + 1) % gradients.count
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
