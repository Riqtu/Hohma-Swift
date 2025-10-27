import Inject
import SwiftUI

struct RaceSceneView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceViewModel()
    let race: Race?

    init(race: Race? = nil) {
        self.race = race
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя часть с фоном
            Image("SceneBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 140)

            // Основная область с дорогой
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Рассчитываем ширину дороги на основе количества ячеек
                    let cellWidth: CGFloat = 40 + 10  // ширина ячейки + отступы
                    let roadWidth = CGFloat(viewModel.raceCells.count) * cellWidth + 20  // +20 для padding

                    Image("SceneRace")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: roadWidth)  // Ограничиваем ширину

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

                viewModel.loadRace(race)
                // Обновляем состояние скачки при переходе в скачку
                viewModel.refreshRace()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .raceUpdated)) { _ in
            // Обновляем данные при получении уведомления об изменении скачки
            if race != nil {
                viewModel.refreshRace()
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .enableInjection()
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Кнопка хода
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
