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
                    Image("SceneRace")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .padding(.horizontal, -250)

                    LazyVStack(spacing: 10) {
                        ForEach(0..<max(1, viewModel.participants.count), id: \.self) {
                            participantIndex in
                            if participantIndex < viewModel.participants.count {
                                RaceRoadView(
                                    cells: viewModel.raceCells,
                                    participant: viewModel.participants[participantIndex]
                                )
                                .id("road_\(participantIndex)")
                            } else {
                                // Показываем пустую дорогу для preview
                                RaceRoadView(
                                    cells: viewModel.raceCells,
                                    participant: createMockParticipant()
                                )
                                .id("road_\(participantIndex)")
                            }
                        }
                    }
                    .padding(.top, -40)
                    .padding(.vertical, 20)  // Добавляем вертикальные отступы для участников

                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.top, -50)

            bottomBar
        }
        .onAppear {
            if let race = race {
                viewModel.loadRace(race)
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
            // Информация о текущем состоянии
            // HStack {
            //     VStack(alignment: .leading, spacing: 4) {
            //         Text("Скачка: \(viewModel.race?.name ?? "Загрузка...")")
            //             .font(.headline)
            //             .foregroundColor(.primary)

            //         if let participant = viewModel.currentUserParticipant {
            //             Text("Ваша позиция: \(participant.currentPosition + 1)")
            //                 .font(.subheadline)
            //                 .foregroundColor(.secondary)
            //         }
            //     }

            //     Spacer()

            //     // Показываем результат броска кубика
            //     if viewModel.diceRoll > 0 {
            //         VStack {
            //             Text("🎲")
            //                 .font(.title)
            //             Text("\(viewModel.diceRoll)")
            //                 .font(.headline)
            //                 .fontWeight(.bold)
            //         }
            //     }
            // }
            // .padding(.horizontal)

            // Кнопка хода
            Button(action: {
                viewModel.makeMove()
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.fill")
                    }

                    Text(viewModel.isLoading ? "Ход..." : "Ход всех участников")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    viewModel.canMakeMove ? Color("AccentColor") : Color.gray
                )
                .cornerRadius(12)
            }
            .disabled(!viewModel.canMakeMove || viewModel.isLoading)
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
