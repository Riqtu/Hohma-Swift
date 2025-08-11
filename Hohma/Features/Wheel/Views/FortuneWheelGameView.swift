//
//  FortuneWheelGameView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AVFoundation
import SwiftUI
import Inject

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
                if let player = viewModel.player {
                    VideoBackgroundView(player: player)
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
            viewModel.pauseVideo()
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
