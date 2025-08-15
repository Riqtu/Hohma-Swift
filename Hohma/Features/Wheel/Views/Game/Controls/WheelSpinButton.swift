//
//  WheelSpinButton.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct WheelSpinButton: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0

    let isSocketReady: Bool

    private var accentColor: Color {
        Color(hex: wheelState.accentColor)
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                wheelState.spinWheel()
            }
        }) {
            GeometryReader { geometry in
                ZStack {
                    // Внешний круг с градиентом
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: isPressed ? 2 : 8,
                            x: 0,
                            y: isPressed ? 1 : 4
                        )
                        .scaleEffect(isPressed ? 0.95 : 1.0)

                    // Иконка вращения с идеальным центрированием
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(rotationAngle))
                        .position(
                            x: geometry.size.width / 2 + 1,
                            y: geometry.size.height / 2 + 1
                        )

                }
            }
            .frame(width: 80, height: 80)
        }
        .disabled(wheelState.spinning || wheelState.sectors.count <= 1 || !isSocketReady)
        .opacity(
            (wheelState.spinning || wheelState.sectors.count <= 1 || !isSocketReady)
                ? 0.5 : 1.0
        )
        .enableInjection()
    }
}

#Preview {
    WheelSpinButton(
        wheelState: WheelState(),
        isSocketReady: true
    )
    .background(Color.black)
}
