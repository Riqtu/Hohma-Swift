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
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isClosing = false

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
                    // Заголовок
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            Text("XOXMA")
                                .font(.custom("Luckiest Guy", size: 32))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            HStack(spacing: 4) {
                                Text("Свайп для фильмов")
                                    .font(.caption2)
                                    .foregroundColor(
                                        Color(hex: viewModel.wheelState.accentColor).opacity(0.7))
                                Image(systemName: "arrow.left")
                                    .font(.caption)
                                    .foregroundColor(
                                        Color(hex: viewModel.wheelState.accentColor).opacity(0.7)
                                    )
                                    .offset(x: isDragging ? -10 : (swipeAnimation ? -5 : 0))
                                    .animation(
                                        .easeInOut(duration: 0.2),
                                        value: isDragging || swipeAnimation)
                            }
                        }
                        .scaleEffect(swipeAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: swipeAnimation)

                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.bottom, -10)

                    // Основная область с колесом
                    ScrollView(showsIndicators: false) {
                        // Панель пользователей
                        VStack {
                            UsersPanelView(
                                viewModel: viewModel,
                                accentColor: viewModel.wheelState.accentColor
                            )
                            Spacer()
                        }

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
                                userCoins: viewModel.currentUserCoins,
                                isSocketReady: viewModel.isSocketReady
                            )

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

                        // Панель секторов
                        VStack(spacing: 16) {
                            SectorsTableView(
                                sectors: viewModel.wheelState.sectors + viewModel.wheelState.losers,
                                title: "Фильмы",
                                accentColor: viewModel.wheelState.accentColor
                            )

                            Spacer()
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
                .onChanged { value in
                    // Отслеживаем движение пальца влево
                    if value.translation.width < 0 && abs(value.translation.height) < 50 {
                        isDragging = true
                        isClosing = false
                        dragOffset = abs(value.translation.width)

                        // Показываем экран только при достаточном свайпе
                        if abs(value.translation.width) > 30 {
                            showingSectorsFullScreen = true
                        }
                    }
                    // Отслеживаем движение пальца вправо для закрытия
                    else if value.translation.width > 0 && abs(value.translation.height) < 50
                        && showingSectorsFullScreen
                    {
                        isDragging = true
                        isClosing = true
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    isDragging = false

                    if isClosing {
                        // Логика для закрытия экрана
                        if value.translation.width > 100 && abs(value.translation.height) < 50 {
                            // Полное закрытие
                            withAnimation(.easeIn(duration: 0.3)) {
                                showingSectorsFullScreen = false
                            }
                        } else {
                            // Возвращаем экран на место с анимацией фона
                            withAnimation(.easeOut(duration: 0.3)) {
                                // Экран остается открытым, фон возвращается к полной прозрачности
                            }
                        }
                    } else {
                        // Логика для открытия экрана
                        if value.translation.width < -50 && abs(value.translation.height) < 50 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                swipeAnimation = true
                            }

                            // Оставляем экран открытым
                            showingSectorsFullScreen = true
                            swipeAnimation = false
                        } else if showingSectorsFullScreen {
                            // Если экран уже показан, но свайп недостаточный, оставляем его открытым
                        } else {
                            // Если экран не показан и свайп недостаточный, скрываем с анимацией
                            withAnimation(.easeIn(duration: 0.3)) {
                                showingSectorsFullScreen = false
                            }
                        }
                    }

                    dragOffset = 0
                    isClosing = false
                }
        )
        .overlay(
            Group {
                if showingSectorsFullScreen {
                    SectorsSlideView(
                        isPresented: $showingSectorsFullScreen,
                        sectors: viewModel.wheelState.sectors + viewModel.wheelState.losers,
                        title: "Фильмы",
                        accentColor: viewModel.wheelState.accentColor,
                        dragOffset: dragOffset,
                        isDragging: isDragging,
                        isClosing: isClosing
                    )
                }
            }
        )
        .onAppear {
            viewModel.setupVideoBackground()
        }
        .onDisappear {
            viewModel.cleanup()
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
