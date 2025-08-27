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
    @State private var isPortraitOrientation = true
    @State private var lastOrientationUpdate = Date()

    init(wheelData: WheelWithRelations, currentUser: AuthUser?) {
        self._viewModel = StateObject(
            wrappedValue: FortuneWheelViewModel(wheelData: wheelData, currentUser: currentUser))
    }

    // MARK: - Computed Properties

    private var backgroundView: some View {
        let urlString = viewModel.wheelState.backVideo
        if !urlString.isEmpty, let url = URL(string: urlString) {
            return AnyView(
                StreamVideoView(url: url)
                    .ignoresSafeArea())
        } else if viewModel.isVideoReady {
            return AnyView(
                AnimatedGradientBackground()
                    .ignoresSafeArea())
        } else {
            return AnyView(
                AnimatedGradientBackground()
                    .ignoresSafeArea())
        }
    }

    private var errorOverlay: some View {
        Group {
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

    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            swipeHintView
            wheelContent(geometry: geometry)
            Spacer()
        }
    }

    private var swipeHintView: some View {
        HStack(spacing: 4) {
            Text("Свайп для фильмов")
                .font(.caption2)
                .foregroundColor(Color(hex: viewModel.wheelState.accentColor).opacity(0.8))
            Image(systemName: "arrow.left")
                .font(.caption2)
                .foregroundColor(Color(hex: viewModel.wheelState.accentColor).opacity(0.8))
                .offset(x: swipeAnimation ? -2 : 0)
                .animation(.easeInOut(duration: 0.2), value: swipeAnimation)
        }
        .padding(.top, 8)
    }

    private func wheelContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            wheelLayout(geometry: geometry)
            connectionIndicator
        }
        .padding(.horizontal, 20)
    }

    private func wheelLayout(geometry: GeometryProxy) -> some View {
        // Специальная логика для iPad в портретной ориентации
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let currentIsPortrait = geometry.size.height > geometry.size.width * 1.1

        // Для iPad используем более консервативный подход
        let threshold: CGFloat = isIPad ? 100 : 50

        // Update orientation state with debouncing for iPad
        if abs(geometry.size.height - geometry.size.width) > threshold {
            let now = Date()
            if now.timeIntervalSince(lastOrientationUpdate) > 0.5 {
                DispatchQueue.main.async {
                    isPortraitOrientation = currentIsPortrait
                    lastOrientationUpdate = now
                }
            }
        }

        return Group {
            if isPortraitOrientation {
                portraitLayout(geometry: geometry)
            } else {
                landscapeLayout(geometry: geometry)
            }
        }
    }

    private func portraitLayout(geometry: GeometryProxy) -> some View {
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

            if !viewModel.wheelState.sectors.contains(where: { $0.winner }) {
                WheelControlsView(
                    wheelState: viewModel.wheelState,
                    viewModel: viewModel,
                    userCoins: viewModel.currentUserCoins,
                    isSocketReady: viewModel.isSocketReady
                )
            }
        }
    }

    private func landscapeLayout(geometry: GeometryProxy) -> some View {
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

            if !viewModel.wheelState.sectors.contains(where: { $0.winner }) {
                WheelControlsView(
                    wheelState: viewModel.wheelState,
                    viewModel: viewModel,
                    userCoins: viewModel.currentUserCoins,
                    isSocketReady: viewModel.isSocketReady
                )
            }
        }
    }

    private var connectionIndicator: some View {
        Group {
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
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                mainContentView(geometry: geometry)
                errorOverlay
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
