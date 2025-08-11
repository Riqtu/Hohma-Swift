//
//  GlassCardView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI

struct GlassCardView<Content: View>: View {
    let content: Content
    let blurRadius: CGFloat
    let opacity: Double

    init(
        blurRadius: CGFloat = 10,
        opacity: Double = 0.2,
        @ViewBuilder content: () -> Content
    ) {
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// Расширение для удобного использования
extension View {
    func glassCard(
        blurRadius: CGFloat = 10,
        opacity: Double = 0.2
    ) -> some View {
        GlassCardView(blurRadius: blurRadius, opacity: opacity) {
            self
        }
    }
}

#Preview {
    ZStack {
        // Имитация фона
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Стеклянная карточка")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Это пример стеклянного эффекта на градиентном фоне")
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassCard()
    }
}
