import Inject
import SwiftUI

struct RaceSceneView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceViewModel()
    @StateObject private var themeManager = RaceThemeManager()
    let race: Race?
    @State private var showingJoinMovieSheet = false
    
    // Отслеживаем изменения темы для обновления музыки
    private var currentTheme: RaceTheme {
        themeManager.currentTheme
    }

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
                    AppLogger.shared.debug(
                        "RaceSceneView: Using background image: \(themeManager.currentTheme.sceneBackgroundImageName)", category: .ui)
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
                            AppLogger.shared.debug(
                                "RaceSceneView: Using race image: \(themeManager.currentTheme.sceneRaceImageName)", category: .ui)
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
                                            AppLogger.shared.debug(
                                                "RaceSceneView: участник \(participantIndex), currentStepPosition = \(pos)", category: .ui)
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
                AppLogger.shared.debug(
                    "RaceSceneView: Loading race with \(race.participants?.count ?? 0) participants", category: .ui)

                // Устанавливаем тему из данных гонки
                AppLogger.shared.debug("RaceSceneView: Race theme from API: '\(race.theme)'", category: .ui)
                AppLogger.shared.debug("RaceSceneView: Road theme from API: '\(race.road.theme)'", category: .ui)
                themeManager.setThemeFromRace(race.road.theme)
                AppLogger.shared.debug(
                    "RaceSceneView: Current theme after setting: \(themeManager.currentTheme.rawValue)", category: .ui)

                viewModel.loadRace(race)
                // Обновляем состояние скачки при переходе в скачку
                viewModel.refreshRace()

                // Предзагружаем аватарки участников для оптимизации отображения
                if let participants = race.participants {
                    AvatarCacheService.shared.preloadAvatars(for: participants)
                }
                
                // Запускаем фоновую музыку для текущей темы
                RaceAudioService.shared.playBackgroundMusic(for: themeManager.currentTheme)
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
                
                // Обновляем фоновую музыку при изменении темы
                RaceAudioService.shared.playBackgroundMusic(for: themeManager.currentTheme)
            }
        }
        .onDisappear {
            // Очищаем кэш аватарок при выходе из скачки для освобождения памяти
            if let participants = race?.participants {
                for participant in participants {
                    AvatarCacheService.shared.clearCache(for: participant.user.id)
                }
            }
            
            // Останавливаем фоновую музыку при выходе из скачки
            RaceAudioService.shared.stopAll()
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
                winnerId: viewModel.winnerId,
                onWinnerSelected: { winnerId in
                    // Если победитель уже определен сервером, просто закрываем экран
                    if viewModel.winnerId == winnerId {
                        viewModel.showingWinnerSelection = false
                        viewModel.raceFinished = true
                    } else {
                        // Если победитель не определен, отправляем выбор на сервер
                        viewModel.setWinner(participantId: winnerId)
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
        .sheet(isPresented: $showingJoinMovieSheet) {
            if let race = viewModel.race ?? race {
                RaceJoinMovieView(race: race) { selection in
                    viewModel.joinRace(movie: selection) {
                        showingJoinMovieSheet = false
                    }
                }
            } else {
                Text("Скачка не загружена")
            }
        }
        .onChange(of: themeManager.currentTheme) { oldTheme, newTheme in
            // Обновляем музыку при изменении темы
            if oldTheme != newTheme {
                RaceAudioService.shared.playBackgroundMusic(for: newTheme)
            }
        }
        .enableInjection()
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if viewModel.canJoinCurrentRace {
                Button(action: {
                    showingJoinMovieSheet = true
                }) {
                    HStack {
                        Image(systemName: "film")
                        Text("Добавить фильм в скачку")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color("AccentColor"))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            if viewModel.canStartRace {
                Button(action: {
                    viewModel.startRace()
                }) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Начать скачку")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
                .padding(.horizontal)
            }
            // Кнопка хода или статус гонки
            // Показываем статус завершенной гонки только если экран победителя уже был показан
            // Это предотвращает преждевременное отображение информации о победителе
            if let race = viewModel.race, race.status == .finished, viewModel.raceFinished, !viewModel.showingWinnerSelection {
                // Показываем статус завершенной гонки с информацией о победителе
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
            } else if let race = viewModel.race, race.status == .finished, (!viewModel.raceFinished || viewModel.showingWinnerSelection) {
                // Гонка завершена, но экран победителя еще не показан или показывается экран выбора
                // Показываем только статус без информации о победителе
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Гонка завершена")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    
                    if viewModel.isAnimating || viewModel.showingWinnerSelection {
                        Text("Определяем победителя...")
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

        do {
            return try JSONDecoder().decode(RaceParticipant.self, from: jsonData)
        } catch {
            // В Preview используем fatalError, так как это только для разработки
            // В production коде это не должно использоваться
            fatalError("Failed to decode RaceParticipant in Preview: \(error.localizedDescription)")
        }
    }
}

#Preview {
    RaceSceneView()
}
