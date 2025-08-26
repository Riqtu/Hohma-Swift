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
    @State private var showingSectorsFullScreen = false
    @State private var swipeAnimation = false

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
                VStack(spacing: 16) {
                    // Подсказка о свайпе
                    HStack(spacing: 4) {
                        Text("Свайп для фильмов")
                            .font(.caption2)
                            .foregroundColor(
                                Color(hex: viewModel.wheelState.accentColor).opacity(0.8))
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                            .foregroundColor(
                                Color(hex: viewModel.wheelState.accentColor).opacity(0.8)
                            )
                            .offset(x: swipeAnimation ? -2 : 0)
                            .animation(.easeInOut(duration: 0.2), value: swipeAnimation)
                    }
                    .padding(.top, 8)

                    // Основная область с колесом
                    // Панель пользователей

                    // Центральная область с колесом
                    VStack(spacing: 16) {
                        // Колесо фортуны
                        Group {
                            if geometry.size.height > geometry.size.width {
                                // Вертикальная ориентация - VStack
                                VStack(spacing: 16) {
                                    UsersPanelView(
                                        viewModel: viewModel,
                                        accentColor: viewModel.wheelState.accentColor
                                    )
                                    FortuneWheelView(
                                        wheelState: viewModel.wheelState,
                                        size: viewModel.calculateWheelSize(for: geometry)
                                    )
                                    .frame(maxWidth: .infinity)

                                    // Управление (скрываем если есть победитель)
                                    if !(viewModel.wheelState.losers.count > 0
                                        && viewModel.wheelState.sectors.count == 1)
                                    {
                                        WheelControlsView(
                                            wheelState: viewModel.wheelState,
                                            viewModel: viewModel,
                                            userCoins: viewModel.currentUserCoins,
                                            isSocketReady: viewModel.isSocketReady
                                        )
                                    }
                                }
                            } else {
                                // Горизонтальная ориентация - HStack
                                HStack(spacing: 16) {
                                    UsersPanelView(
                                        viewModel: viewModel,
                                        accentColor: viewModel.wheelState.accentColor
                                    )

                                    GeometryReader { wheelGeometry in
                                        FortuneWheelView(
                                            wheelState: viewModel.wheelState,
                                            size: viewModel.calculateWheelSize(
                                                for: geometry,
                                                availableWidth: wheelGeometry.size.width
                                            )
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .position(
                                            x: wheelGeometry.size.width / 2,
                                            y: wheelGeometry.size.height / 2
                                        )
                                    }

                                    // Управление (скрываем если есть победитель)
                                    if !(viewModel.wheelState.losers.count > 0
                                        && viewModel.wheelState.sectors.count == 1)
                                    {
                                        WheelControlsView(
                                            wheelState: viewModel.wheelState,
                                            viewModel: viewModel,
                                            userCoins: viewModel.currentUserCoins,
                                            isSocketReady: viewModel.isSocketReady
                                        )
                                    }
                                }
                            }
                        }

                        // Индикатор подключения
                        if !viewModel.isSocketReady {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Подключение к игре...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }

                // Ошибка подключения
                if let error = viewModel.error {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Свайп влево для открытия
                    if value.translation.width < -100 && abs(value.translation.height) < 50 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            swipeAnimation = true
                        }
                        showingSectorsFullScreen = true
                        swipeAnimation = false
                    }
                }
        )
        .navigationDestination(isPresented: $showingSectorsFullScreen) {
            SectorsSlideView(
                isPresented: $showingSectorsFullScreen,
                sectors: viewModel.wheelState.sectors + viewModel.wheelState.losers,
                title: "Фильмы",
                accentColor: viewModel.wheelState.accentColor,
                viewModel: viewModel
            )
        }
        .onAppear {
            viewModel.setupVideoBackground()
        }
        .onDisappear {
            viewModel.cleanup()
            // Уведомляем об обновлении данных колеса только если были изменения
            if viewModel.wheelState.sectors.count > 0 || viewModel.wheelState.losers.count > 0 {
                NotificationCenter.default.post(name: .wheelDataUpdated, object: nil)
            }
        }

        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .scaleEffect(swipeAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: swipeAnimation)
                    .padding(.top, 10)
            }
        }
        .overlay(
            Group {
                if let error = viewModel.error {
                    VStack {
                        NotificationView(
                            message: error,
                            type: .error
                        ) {
                            viewModel.error = nil
                        }
                        Spacer()
                    }
                    .padding(.top, 50)
                }

                if let successMessage = viewModel.successMessage {
                    VStack {
                        NotificationView(
                            message: successMessage,
                            type: .success
                        ) {
                            viewModel.successMessage = nil
                        }
                        Spacer()
                    }
                    .padding(.top, 50)
                }
            }
        )
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
