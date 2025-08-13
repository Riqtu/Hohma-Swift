//
//  FortuneWheelGameView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AVFoundation
import Inject
import SwiftUI

struct FortuneWheelGameView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel: FortuneWheelViewModel

    init(wheelData: WheelWithRelations, currentUser: AuthUser?) {
        self._viewModel = StateObject(
            wrappedValue: FortuneWheelViewModel(wheelData: wheelData, currentUser: currentUser))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Видео фон
                let urlString = viewModel.wheelState.backVideo
                if !urlString.isEmpty,
                    let url = URL(string: urlString)
                {
                    // Используем новый StreamVideoView для внешних URL
                    StreamVideoView(url: url)
                        .ignoresSafeArea()
                } else if viewModel.isVideoReady {
                    // Fallback на градиент если видео не готово
                    AnimatedGradientBackground()
                        .ignoresSafeArea()
                } else {
                    // Показываем градиент пока видео загружается
                    AnimatedGradientBackground()
                        .ignoresSafeArea()
                }

                // Основной контент
                VStack(spacing: 20) {
                    // Заголовок
                    WheelHeaderView(
                        hasWinner: viewModel.hasWinner,
                        winnerUser: viewModel.winnerUser
                    )

                    // Основная область с колесом
                    HStack(spacing: 20) {
                        // Панель пользователей
                        // VStack {
                        //     UsersPanelView(
                        //         users: viewModel.users,
                        //         accentColor: viewModel.wheelState.accentColor
                        //     )
                        //     Spacer()
                        // }

                        // Центральная область с колесом
                        VStack(spacing: 16) {
                            // Колесо фортуны
                            FortuneWheelView(
                                wheelState: viewModel.wheelState,
                                size: viewModel.calculateWheelSize(for: geometry) + 120
                            )

                            // Управление
                            WheelControlsView(
                                wheelState: viewModel.wheelState,
                                userCoins: viewModel.currentUserCoins
                            )
                        }

                        // Панель секторов
                        // VStack(spacing: 16) {
                        //     SectorsTableView(
                        //         sectors: viewModel.wheelState.sectors,
                        //         title: "Фильмы",
                        //         accentColor: viewModel.wheelState.accentColor
                        //     )

                        //     SectorsTableView(
                        //         sectors: viewModel.wheelState.losers,
                        //         title: "Выбывшие",
                        //         accentColor: viewModel.wheelState.accentColor
                        //     )

                        //     Spacer()
                        // }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
        }
        .onAppear {
            viewModel.setupVideoBackground()
        }
        .onDisappear {
            // Не останавливаем видео при закрытии игры
            // viewModel.pauseVideo()
        }
        .enableInjection()
    }
}

#Preview {
    FortuneWheelGameView(
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
    )
}
