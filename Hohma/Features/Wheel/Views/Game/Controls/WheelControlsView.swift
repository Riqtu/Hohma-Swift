//
//  WheelControlsView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct WheelControlsView: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState
    @ObservedObject var viewModel: FortuneWheelViewModel
    @State private var showingSettings = false
    @State private var showingBets = false
    @State private var showingAddSector = false

    let userCoins: Int
    let isSocketReady: Bool

    private var accentColor: Color {
        Color(hex: wheelState.accentColor)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Основная панель с большой круглой кнопкой
            HStack(spacing: 20) {
                // Счетчик секторов

                // Большая круглая кнопка вращения
                WheelSpinButton(
                    wheelState: wheelState,
                    isSocketReady: isSocketReady
                )

            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            // .background(
            //     RoundedRectangle(cornerRadius: 12)
            //         .fill(Color.black.opacity(0.3))
            //         .overlay(
            //             RoundedRectangle(cornerRadius: 12)
            //                 .stroke(Color.white, lineWidth: 1)
            //         )
            // )

            // Кнопки управления
            HStack(spacing: 20) {
                // Кнопка перемешивания
                Button(action: {
                    wheelState.shuffleSectors()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.title2)

                    }
                    .foregroundColor(.white)

                }
                .disabled(wheelState.spinning || !isSocketReady)
                .opacity((wheelState.spinning || !isSocketReady) ? 0.5 : 1.0)

                // Кнопка ставок
                Button(action: {
                    showingBets = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.title2)

                    }
                    .foregroundColor(.white)

                }
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                // Кнопка добавления сектора
                Button(action: {
                    showingAddSector = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)

                    }
                    .foregroundColor(.white)

                }
                .disabled(wheelState.spinning || !isSocketReady)
                .opacity((wheelState.spinning || !isSocketReady) ? 0.5 : 1.0)

            }

            // Информация о монетах
            if userCoins > 0 {
                Text("Ваши монеты: \(userCoins)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
        }
        .sheet(isPresented: $showingSettings) {
            WheelSettingsView(wheelState: wheelState)
        }
        .sheet(isPresented: $showingBets) {
            WheelBetsView(wheelState: wheelState, userCoins: userCoins)
        }
        .sheet(isPresented: $showingAddSector) {
            AddSectorFormView(
                wheelId: viewModel.wheelId,
                currentUser: viewModel.user,
                accentColor: wheelState.accentColor,
                onSectorCreated: { sector in
                    viewModel.addSector(sector)
                }
            )
        }
        .enableInjection()
    }
}

// Попап с настройками
struct WheelSettingsView: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState
    @Environment(\.dismiss) private var dismiss

    private var accentColor: Color {
        Color(hex: wheelState.accentColor)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Скорость вращения
                VStack(alignment: .leading, spacing: 10) {
                    Text("Скорость вращения")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        Text("Медленно")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Slider(
                            value: $wheelState.speed,
                            in: 5...15,
                            step: 1
                        )
                        .accentColor(accentColor)

                        Text("Быстро")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text("Текущая скорость: \(Int(wheelState.speed))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Автоматическое вращение
                HStack {
                    Text("Авто-вращение")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Toggle("", isOn: $wheelState.autoSpin)
                        .toggleStyle(SwitchToggleStyle(tint: accentColor))
                }

                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}

// Попап со ставками
struct WheelBetsView: View {
    @ObserveInjection var inject
    @ObservedObject var wheelState: WheelState
    @Environment(\.dismiss) private var dismiss

    let userCoins: Int

    private var accentColor: Color {
        Color(hex: wheelState.accentColor)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Информация о ставках
                VStack(spacing: 10) {
                    Text("Ставки")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Ваши монеты: \(userCoins)")
                        .font(.headline)
                        .foregroundColor(accentColor)

                    Text("Функция ставок будет добавлена в следующем обновлении")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Ставки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}

#Preview {
    WheelControlsView(
        wheelState: WheelState(),
        viewModel: FortuneWheelViewModel(
            wheelData: WheelWithRelations(
                id: "test",
                name: "Тестовое колесо",
                status: .active,
                createdAt: Date(),
                updatedAt: Date(),
                themeId: "theme1",
                userId: "user1",
                sectors: [Sector.mock, Sector.mock],
                bets: [],
                theme: WheelTheme.mock,
                user: AuthUser.mock
            ),
            currentUser: AuthUser.mock
        ),
        userCoins: 37,
        isSocketReady: true
    )
    .background(Color.black)
}
