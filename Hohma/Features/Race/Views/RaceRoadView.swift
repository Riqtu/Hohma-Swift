import Inject
import SwiftUI

struct RaceRoadView: View {
    @ObserveInjection var inject
    let cells: [RaceCellData]
    let participant: RaceParticipant

    var body: some View {
        VStack {
            LazyHStack(spacing: 0) {
                ForEach(cells) { cellData in
                    RaceCellView(
                        cellData: cellData,
                        participant: participant
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

// Mock структуры для preview
struct MockRaceUser {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?
}

struct MockRaceParticipant {
    let id: String
    let raceId: String
    let userId: String
    let currentPosition: Int
    let totalMoves: Int
    let boostUsed: Int
    let obstaclesHit: Int
    let finalPosition: Int?
    let prize: Int?
    let isFinished: Bool
    let joinedAt: String
    let finishedAt: String?
    let user: MockRaceUser
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

    let mockUser = MockRaceUser(
        id: "1",
        name: "Test",
        username: "test",
        avatarUrl: nil
    )

    let mockParticipant = MockRaceParticipant(
        id: "1",
        raceId: "1",
        userId: "1",
        currentPosition: 0,
        totalMoves: 0,
        boostUsed: 0,
        obstaclesHit: 0,
        finalPosition: nil,
        prize: nil,
        isFinished: false,
        joinedAt: "",
        finishedAt: nil,
        user: mockUser
    )

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

    return RaceRoadView(cells: raceCells, participant: participant)
}
