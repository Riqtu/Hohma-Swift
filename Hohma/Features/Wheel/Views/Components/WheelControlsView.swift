//
//  WheelControlsView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

struct WheelControlsView: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState
    let userCoins: Int

    var body: some View {
        VStack(spacing: 12) {
            // Кнопки управления
            HStack(spacing: 12) {
                // Кнопка вращения
                Button(action: {
                    wheelState.spinWheel()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Крутить")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: wheelState.accentColor))
                    )
                }
                .disabled(wheelState.spinning || wheelState.sectors.count <= 1)
                .opacity(wheelState.spinning || wheelState.sectors.count <= 1 ? 0.5 : 1.0)

                // Кнопка перемешивания
                Button(action: {
                    wheelState.shuffleSectors()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.caption)
                        Text("Перемешать")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: wheelState.accentColor), lineWidth: 1)
                    )
                }
                .disabled(wheelState.spinning)
                .opacity(wheelState.spinning ? 0.5 : 1.0)
            }

            // Настройки
            VStack(spacing: 8) {
                // Скорость вращения
                VStack(alignment: .leading, spacing: 4) {
                    Text("Скорость")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        Text("Медленно")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Slider(
                            value: $wheelState.speed,
                            in: 5...15,
                            step: 1
                        )
                        .accentColor(Color(hex: wheelState.accentColor))

                        Text("Быстро")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Автоматическое вращение
                HStack {
                    Toggle("Авто-вращение", isOn: $wheelState.autoSpin)
                        .font(.caption)
                        .foregroundColor(.white)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: wheelState.accentColor)))

                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.2))
            )

            // Информация о монетах
            if userCoins > 0 {
                HStack {
                    Image(systemName: "coins")
                        .foregroundColor(Color(hex: wheelState.accentColor))
                        .font(.caption)

                    Text("Ваши монеты: \(userCoins)")
                        .font(.caption)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: wheelState.accentColor).opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: wheelState.accentColor).opacity(0.3), lineWidth: 1)
                )
        )
        .enableInjection()
    }
}

#Preview {
    WheelControlsView(
        wheelState: WheelState(),
        userCoins: 1000
    )
    .background(Color.black)
}
