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

    var body: some View {
        ZStack {
            // Контейнер для правильного центрирования
            Color.clear
                .frame(width: size, height: size)
            // Фон колеса
            Circle()
                .fill(Color(hex: wheelState.mainColor))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color(hex: wheelState.accentColor), lineWidth: 4)
                )
                .shadow(
                    color: Color(hex: wheelState.accentColor).opacity(0.5), radius: 10, x: 4, y: 10
                )

            // Сектора колеса
            if !wheelState.sectors.isEmpty {
                ForEach(Array(wheelState.sectors.enumerated()), id: \.element.id) { index, sector in
                    WheelSectorView(
                        sector: sector,
                        index: index,
                        totalSectors: wheelState.sectors.count,
                        size: size
                    )
                }
                .rotationEffect(.degrees(wheelState.rotation))
                .animation(
                    wheelState.spinning ? .easeInOut(duration: wheelState.speed) : .default,
                    value: wheelState.rotation)
            }

            // Центральная кнопка
            Circle()
                .fill(Color(hex: wheelState.mainColor))
                .frame(width: size / 5, height: size / 5)
                .overlay(
                    Circle()
                        .stroke(Color(hex: wheelState.accentColor), lineWidth: 4)
                )
                .shadow(
                    color: Color(hex: wheelState.accentColor).opacity(0.5), radius: 10, x: 4, y: 10
                )
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: size / 15, weight: .bold))
                        .foregroundColor(Color(hex: wheelState.accentColor))
                        .rotationEffect(.degrees(-45))
                )

            // Указатель
            if wheelState.sectors.count > 1 {
                Triangle()
                    .fill(Color(hex: wheelState.accentColor))
                    .frame(width: 30, height: 35)
                    .rotationEffect(.degrees(180))
                    .offset(y: -(size) / 2)  // Учитываем размер основного круга с отступом
                    .shadow(
                        color: Color(hex: wheelState.accentColor).opacity(0.5), radius: 5, x: 2,
                        y: 5)
            }

            // Экран победителя
            if wheelState.losers.count > 0 && wheelState.sectors.count == 1 {
                WinnerOverlayView(sector: wheelState.sectors[0])
            }
        }
        .enableInjection()
    }
}

#Preview {
    let wheelState = WheelState()
    wheelState.sectors = [Sector.mockWithPattern, Sector.mock, Sector.mock2]
    return FortuneWheelView(wheelState: wheelState, size: 200)
}
