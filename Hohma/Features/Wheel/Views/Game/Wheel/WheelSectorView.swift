//
//  WheelSectorView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

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
            // Создаем путь сектора для обрезки
            let sectorPath = Path { path in
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

            // Если есть паттерн, используем его с обрезкой
            if let pattern = sector.pattern {
                AsyncImage(url: URL(string: pattern)) { image in
                    ZStack {
                        // Фоновое размытое изображение (как в React версии)
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .blur(radius: 2)
                            .opacity(0.9)
                            .rotationEffect(.degrees(startAngle + anglePerSector / 2 + 90))
                            .clipShape(sectorPath)

                        // Основное изображение с позиционированием
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // .frame(width: size * 0.8, height: size * 0.8)
                            .scaleEffect(1 + (sector.patternPosition?.z ?? 0) / 100)
                            .offset(
                                x: (sector.patternPosition?.x ?? 0) * (size / 200),
                                y: (sector.patternPosition?.y ?? 0) * (size / 200)
                            )
                            .rotationEffect(.degrees(startAngle + anglePerSector / 2 + 90))
                            .clipShape(sectorPath)
                    }
                    .overlay(
                        sectorPath
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                } placeholder: {
                    // Fallback на цвет если изображение не загрузилось
                    sectorPath
                        .fill(
                            Color(
                                hue: sector.color.h / 360,
                                saturation: sector.color.s / 100,
                                brightness: sector.color.l / 100
                            )
                        )
                        .overlay(
                            sectorPath
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                }
            } else {
                // Если паттерна нет, используем цвет
                sectorPath
                    .fill(
                        Color(
                            hue: sector.color.h / 360,
                            saturation: sector.color.s / 100,
                            brightness: sector.color.l / 100
                        )
                    )
                    .overlay(
                        sectorPath
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
            }

            // Текст сектора
            if !sector.labelHidden {
                Text(sector.label)
                    .font(.system(size: min(size / 12, 16), weight: .bold))
                    .foregroundColor(
                        sector.labelColor != nil
                            ? Color(hex: sector.labelColor!)
                            : .white
                    )
                    .multilineTextAlignment(.center)
                    .rotationEffect(.degrees(textAngle))
                    .offset(x: textOffsetX, y: textOffsetY)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)  // Фиксируем размер контейнера
        .enableInjection()
    }
}

#Preview {
    WheelSectorView(
        sector: Sector.mock,
        index: 0,
        totalSectors: 3,
        size: 200
    )
}
