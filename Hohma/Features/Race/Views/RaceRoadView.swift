import Inject
import SwiftUI

struct RaceRoadView: View {
    @ObserveInjection var inject
    let cells: [RaceCellData]
    let participant: RaceParticipant
    let isAnimating: Bool
    let animationProgress: Double
    let previousPosition: Int?

    // Новые параметры для пошаговой анимации
    let currentStepPosition: Double?
    let isJumping: Bool
    let animationStepProgress: Double?

    var body: some View {
        VStack {
            LazyHStack(spacing: 0) {
                ForEach(cells) { cellData in
                    RaceCellView(
                        cellData: cellData,
                        participant: participant,
                        isAnimating: isAnimating,
                        animationProgress: animationProgress,
                        previousPosition: previousPosition,
                        currentStepPosition: currentStepPosition,
                        isJumping: isJumping,
                        animationStepProgress: animationStepProgress
                    )
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 120)
        .padding(.bottom, -90)
        .enableInjection()
    }
}

#Preview {
    let raceCells = (0..<35).map { index in
        RaceCellData(
            position: index,
            isActive: index == 0,
            type: .normal,
            participants: []
        )
    }

    // Создаем RaceParticipant из JSON для preview
    let jsonData = """
        {
            "id": "1",
            "raceId": "1",
            "userId": "1",
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
                "id": "1",
                "name": "Test",
                "username": "test",
                "avatarUrl": null
            }
        }
        """.data(using: .utf8)!

    let participant = try! JSONDecoder().decode(RaceParticipant.self, from: jsonData)

    return RaceRoadView(
        cells: raceCells,
        participant: participant,
        isAnimating: false,
        animationProgress: 0.0,
        previousPosition: nil,
        currentStepPosition: nil,
        isJumping: false,
        animationStepProgress: nil
    )
}
