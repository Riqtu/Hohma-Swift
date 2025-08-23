//
//  FortuneWheelView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct FortuneWheelView: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState

    let size: CGFloat

    private var accentColor: Color {
        Color(hex: wheelState.accentColor)
    }

    private var mainColor: Color {
        extractHexFromColorMix(wheelState.mainColor) ?? Color(hex: wheelState.mainColor)
    }

    private func extractHexFromColorMix(_ colorString: String) -> Color? {
        // Ищем hex цвет в строке color-mix
        let pattern = "#[0-9A-Fa-f]{6}"
        if let range = colorString.range(of: pattern, options: .regularExpression) {
            let hexColor = String(colorString[range])
            return Color(hex: hexColor)
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Контейнер для правильного центрирования
            Color.clear
                .frame(width: size, height: size)
            // Фон колеса
            Circle()
                .fill(mainColor)
                .frame(width: size + 35, height: size + 35)
                .overlay(
                    Circle()
                        .stroke(accentColor, lineWidth: 4)
                )
                .shadow(
                    color: accentColor.opacity(0.5), radius: 10, x: 4, y: 10
                )

            // Сектора колеса
            if !wheelState.sectors.isEmpty {
                ForEach(Array(wheelState.sectors.enumerated()), id: \.element.id) { index, sector in
                    WheelSectorView(
                        sector: sector,
                        index: index,
                        totalSectors: wheelState.sectors.count,
                        size: size + 10
                    )
                }
                .rotationEffect(.degrees(wheelState.rotation))
                .animation(
                    wheelState.spinning ? .easeInOut(duration: wheelState.speed) : .default,
                    value: wheelState.rotation)
            }

            // Центральная кнопка
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: size / 5, height: size / 5)
                .overlay(
                    Circle()
                        .stroke(accentColor, lineWidth: 4)
                )
                .shadow(
                    color: accentColor.opacity(0.5), radius: 10, x: 4, y: 10
                )
                .overlay(
                    Text("X")
                        .font(.custom("Luckiest Guy", size: size / 8))
                        .foregroundColor(accentColor)
                        .padding(.top, 15)
                )

            // Указатель
            if wheelState.sectors.count > 1 {
                Triangle()
                    .fill(accentColor)
                    .frame(width: 30, height: 35)
                    .rotationEffect(.degrees(180))
                    .offset(y: -(size) / 2)  // Учитываем размер основного круга с отступом
                    .shadow(
                        color: accentColor.opacity(0.5), radius: 5, x: 2,
                        y: 5)
            }

            // Экран победителя
            if wheelState.losers.count > 0 && wheelState.sectors.count == 1 {
                WinnerOverlayView(
                    sector: wheelState.sectors[0], size: size + 35, mainColor: mainColor)
            }
        }
        .padding(.top, 20)
        .enableInjection()
    }
}

#Preview {
    let wheelState = WheelState()
    wheelState.sectors = [Sector.mockWithPattern, Sector.mock, Sector.mock2]
    return FortuneWheelView(wheelState: wheelState, size: 200)
}
