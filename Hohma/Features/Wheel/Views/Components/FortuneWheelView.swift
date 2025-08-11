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

struct WheelSectorView: View {
    @ObserveInjection var inject

    let sector: Sector
    let index: Int
    let totalSectors: Int
    let size: CGFloat

    var body: some View {
        let anglePerSector = 360.0 / Double(totalSectors)
        let startAngle = Double(index) * anglePerSector - 90  // Начинаем с -90° чтобы первый сектор был сверху
        let endAngle = startAngle + anglePerSector
        let radius = size / 2 - 4  // Радиус с учетом толщины обводки главного круга (4px)
        let textAngle = startAngle + anglePerSector / 2
        let textOffsetX = (radius * 0.7) * cos(textAngle * .pi / 180)
        let textOffsetY = (radius * 0.7) * sin(textAngle * .pi / 180)

        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size / 2, y: size / 2))
                path.addArc(
                    center: CGPoint(x: size / 2, y: size / 2),
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(
                Color(
                    hue: sector.color.h / 360,
                    saturation: sector.color.s / 100,
                    brightness: sector.color.l / 100
                )
            )
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: size / 2, y: size / 2))
                    path.addArc(
                        center: CGPoint(x: size / 2, y: size / 2),
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                Text(sector.label)
                    .font(.system(size: min(size / 12, 16), weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(textAngle))
                    .offset(x: textOffsetX, y: textOffsetY)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
            )
        }
        .frame(width: size, height: size)  // Фиксируем размер контейнера
        .enableInjection()
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct WinnerOverlayView: View {
    let sector: Sector

    var body: some View {
        VStack(spacing: 20) {
            Text("Поздравляем!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let user: AuthUser = sector.user {
                AvatarView(
                    avatarUrl: user.avatarUrl,
                    size: 80,
                    fallbackColor: .gray,
                    showBorder: true,
                    borderColor: .white
                )
            }

            VStack(spacing: 8) {
                Text("\"\(sector.label)\"")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("\(sector.name) - Победитель")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .blur(radius: 10)
        )
        .transition(.opacity.combined(with: .scale))
        .enableInjection()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    FortuneWheelView(wheelState: WheelState(), size: 200)
}
