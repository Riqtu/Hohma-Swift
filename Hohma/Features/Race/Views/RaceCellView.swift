import Inject
import SwiftUI

struct RaceCellView: View {
    @ObserveInjection var inject
    let cellData: RaceCellData
    let participant: RaceParticipant

    var body: some View {
        ZStack {
            // Фон ячейки
            Rectangle()
                .fill(cellBackgroundColor)
                .frame(width: 25, height: 25)
                .cornerRadius(5)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

            // Иконка типа ячейки
            if cellData.type != .normal {
                Image(systemName: cellTypeIcon)
                    .font(.caption)
                    .foregroundColor(cellTypeColor)
            }

            // Показываем участника, если он на этой позиции
            if cellData.position == participant.currentPosition {
                Circle()
                    .fill(participant.isFinished ? .green : .blue)
                    .frame(width: 50, height: 50)
                    .padding(.bottom, 13)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 1)
                    )
                    .zIndex(10)  // Повышаем z-index, чтобы участник был поверх дороги
            }
        }
        .padding(5)
        .padding(.horizontal, 5)
        .zIndex(cellData.position == participant.currentPosition ? 5 : 1)  // Повышаем z-index для ячейки с участником
        .enableInjection()
    }

    // MARK: - Computed Properties
    private var cellBackgroundColor: Color {
        if cellData.position == participant.currentPosition {
            return .blue.opacity(0.3)
        }

        switch cellData.type {
        case .normal:
            return .gray.opacity(0.9)
        case .boost:
            return .green.opacity(0.3)
        case .obstacle:
            return .red.opacity(0.3)
        case .bonus:
            return .yellow.opacity(0.3)
        case .finish:
            return .purple.opacity(0.3)
        }
    }

    private var cellTypeIcon: String {
        switch cellData.type {
        case .normal:
            return ""
        case .boost:
            return "arrow.up"
        case .obstacle:
            return "exclamationmark.triangle"
        case .bonus:
            return "star"
        case .finish:
            return "flag"
        }
    }

    private var cellTypeColor: Color {
        switch cellData.type {
        case .normal:
            return .clear
        case .boost:
            return .green
        case .obstacle:
            return .red
        case .bonus:
            return .yellow
        case .finish:
            return .purple
        }
    }
}

#Preview {
    let cellData = RaceCellData(
        position: 0,
        isActive: true,
        type: .normal,
        participants: []
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

    return RaceCellView(cellData: cellData, participant: participant)
}
