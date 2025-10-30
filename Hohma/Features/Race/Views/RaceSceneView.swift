import Inject
import SwiftUI

struct RaceSceneView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceViewModel()
    @StateObject private var themeManager = RaceThemeManager()
    let race: Race?

    init(race: Race? = nil) {
        self.race = race
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть с фоном
            Image(themeManager.currentTheme.sceneBackgroundImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 140)
                .id(themeManager.currentTheme.sceneBackgroundImageName)
                .onAppear {
                    print(
                        "🎨 RaceSceneView: Using background image: \(themeManager.currentTheme.sceneBackgroundImageName)"
                    )
                }

            // Основная область с дорогой
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Рассчитываем ширину дороги на основе количества ячеек
                    let cellWidth: CGFloat = 40 + 10  // ширина ячейки + отступы
                    let roadWidth = CGFloat(viewModel.raceCells.count) * cellWidth + 20  // +20 для padding

                    Image(themeManager.currentTheme.sceneRaceImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: roadWidth)  // Ограничиваем ширину
                        .id(themeManager.currentTheme.sceneRaceImageName)
                        .onAppear {
                            print(
                                "🎨 RaceSceneView: Using race image: \(themeManager.currentTheme.sceneRaceImageName)"
                            )
                        }

                    VStack(spacing: 10) {
                        ForEach(0..<max(1, viewModel.participants.count), id: \.self) {
                            participantIndex in
                            if participantIndex < viewModel.participants.count {
                                RaceRoadView(
                                    cells: viewModel.raceCells,
                                    participant: viewModel.participants[participantIndex],
                                    isAnimating: viewModel.isAnimating,
                                    animationProgress: viewModel.animationProgress,
                                    previousPosition: viewModel.previousPositions[
                                        viewModel.participants[participantIndex].id],
                                    currentStepPosition: {
                                        let stepPos = viewModel.currentStepPosition[
                                            viewModel.participants[participantIndex].id]
                                        if let pos = stepPos {
                                            print(
                                                "🔄 RaceSceneView: участник \(participantIndex), currentStepPosition = \(pos)"
                                            )
                                        }
                                        return stepPos
                                    }(),
                                    isJumping: viewModel.isJumping[
                                        viewModel.participants[participantIndex].id] ?? false,
                                    animationStepProgress: viewModel.animationStepProgress[
                                        viewModel.participants[participantIndex].id]
                                )
                                .id("road_\(participantIndex)")
                            } else {
                                // Показываем пустую дорогу для preview
                                RaceRoadView(
                                    cells: viewModel.raceCells,
                                    participant: createMockParticipant(),
                                    isAnimating: false,
                                    animationProgress: 0.0,
                                    previousPosition: nil,
                                    currentStepPosition: nil,
                                    isJumping: false,
                                    animationStepProgress: nil
                                )
                                .id("road_\(participantIndex)")
                            }
                        }

                    }
                    .padding(.top, -200)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.top, -50)

            bottomBar
        }
        .onAppear {
            if let race = race {
                print(
                    "🔍 RaceSceneView: Loading race with \(race.participants?.count ?? 0) participants"
                )

                // Устанавливаем тему из данных гонки
                print("🎨 RaceSceneView: Race theme from API: '\(race.theme)'")
                print("🎨 RaceSceneView: Road theme from API: '\(race.road.theme)'")
                themeManager.setThemeFromRace(race.road.theme)
                print(
                    "🎨 RaceSceneView: Current theme after setting: \(themeManager.currentTheme.rawValue)"
                )

                viewModel.loadRace(race)
                // Обновляем состояние скачки при переходе в скачку
                viewModel.refreshRace()

                // Предзагружаем аватарки участников для оптимизации отображения
                if let participants = race.participants {
                    AvatarCacheService.shared.preloadAvatars(for: participants)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .raceUpdated)) { _ in
            // Обновляем данные при получении уведомления об изменении скачки
            if let race = race {
                themeManager.setThemeFromRace(race.road.theme)
                viewModel.refreshRace()

                // Предзагружаем аватарки участников при обновлении скачки
                if let participants = race.participants {
                    AvatarCacheService.shared.preloadAvatars(for: participants)
                }
            }
        }
        .onDisappear {
            // Очищаем кэш аватарок при выходе из скачки для освобождения памяти
            if let participants = race?.participants {
                for participant in participants {
                    AvatarCacheService.shared.clearCache(for: participant.user.id)
                }
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showingWinnerSelection) {
            WinnerSelectionView(
                isPresented: $viewModel.showingWinnerSelection,
                finishingParticipants: viewModel.finishingParticipants,
                participants: viewModel.participants,
                onWinnerSelected: { winnerId in
                    // Показываем экран победителя
                    if let winner = viewModel.participants.first(where: { $0.id == winnerId }) {
                        // Здесь можно добавить логику для показа экрана победителя
                        print(
                            "🏆 Победитель выбран: \(winner.user.name ?? winner.user.username ?? "Неизвестно")"
                        )
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $viewModel.showingDiceRoll) {
            RaceDiceRollView(
                participants: viewModel.participants,
                initialDiceResults: viewModel.diceResults,
                isInitiator: viewModel.isDiceInitiator,
                onNext: {
                    viewModel.diceNext()
                },
                onDiceRollComplete: { diceResults in
                    // Только инициатор делает HTTP ход
                    if viewModel.isDiceInitiator {
                        viewModel.executeMoveWithDiceResults(diceResults)
                    }
                },
                onDismiss: {
                    viewModel.showingDiceRoll = false
                }
            )
        }
        .fullScreenCover(isPresented: $viewModel.raceFinished) {
            if let winnerId = viewModel.winnerId,
                let winner = viewModel.participants.first(where: { $0.id == winnerId }),
                let race = viewModel.race
            {
                RaceWinnerView(
                    isPresented: $viewModel.raceFinished,
                    winner: winner,
                    race: race,
                    onDismiss: {
                        viewModel.raceFinished = false
                    },
                    onNavigateToRaceList: {
                        // Отправляем уведомление о навигации к списку гонок
                        NotificationCenter.default.post(
                            name: .navigationRequested,
                            object: nil,
                            userInfo: ["destination": "race", "force": true]
                        )
                    }
                )
            }
        }
        .enableInjection()
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Кнопка хода или статус гонки
            if let race = viewModel.race, race.status == .finished {
                // Показываем статус завершенной гонки
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Гонка завершена")
                    }
                    .font(.headline)
                    .foregroundColor(.white)

                    if let winner = viewModel.participants.first(where: { $0.finalPosition == 1 }) {
                        Text(
                            "Победитель: \(winner.user.name ?? winner.user.username ?? "Неизвестно")"
                        )
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Кнопка хода для активных гонок
                Button(action: {
                    // Добавляем тактильную обратную связь
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    viewModel.makeMove()
                }) {
                    HStack {
                        if viewModel.isLoading || viewModel.isAnimating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(
                                systemName: viewModel.isAnimating
                                    ? "arrow.right.circle.fill" : "play.fill")
                        }

                        Text(
                            viewModel.isAnimating
                                ? "Движение..."
                                : (viewModel.isLoading ? "Ход..." : "Ход всех участников")
                        )
                        .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        (viewModel.canMakeMove && !viewModel.isAnimating)
                            ? Color("AccentColor") : Color.gray
                    )
                    .cornerRadius(12)
                    .scaleEffect(viewModel.isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: viewModel.isAnimating)
                }
                .disabled(!viewModel.canMakeMove || viewModel.isLoading || viewModel.isAnimating)
                .padding(.horizontal)

                // Показываем дополнительную информацию о состоянии
                if !viewModel.canMakeMove && viewModel.race?.status == .running {
                    VStack(spacing: 4) {
                        if viewModel.currentUserParticipant?.isFinished == true {
                            HStack {
                                Image(systemName: "flag.checkered")
                                    .foregroundColor(.green)
                                Text("Вы финишировали")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .background(Color.gray.opacity(0.2))
    }

    // MARK: - Helper Functions
    private func createMockParticipant() -> RaceParticipant {
        let jsonData = """
            {
                "id": "mock",
                "raceId": "mock",
                "userId": "mock",
                "currentPosition": 0,
                "totalMoves": 0,
                "boostUsed": 0,
                "obstaclesHit": 0,
                "finalPosition": null,
                "prize": null,
                "isFinished": false,
                "joinedAt": "2024-01-01T00:00:00Z",
                "finishedAt": null,
                "user": {
                    "id": "mock",
                    "name": "Mock",
                    "username": "mock",
                    "avatarUrl": null
                }
            }
            """.data(using: .utf8)!

        return try! JSONDecoder().decode(RaceParticipant.self, from: jsonData)
    }
}

#Preview {
    RaceSceneView()
}
