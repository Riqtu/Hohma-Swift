import Foundation
import SwiftUI

// Модель данных для ячейки дороги
struct RaceCellData: Identifiable {
    let id = UUID()
    let position: Int
    let isActive: Bool
    let type: CellType
    let participants: [ParticipantPosition]  // Участники на этой позиции

    enum CellType {
        case normal, boost, obstacle, bonus, finish
    }
}

// Позиция участника на дороге
struct ParticipantPosition: Identifiable {
    let id = UUID()
    let participantId: String
    let userId: String
    let userName: String
    let avatarUrl: String?
    let isCurrentUser: Bool
}

class RaceViewModel: ObservableObject, TRPCServiceProtocol {
    @Published var race: Race?
    @Published var raceCells: [RaceCellData] = []
    @Published var participants: [RaceParticipant] = []
    @Published var currentUserParticipant: RaceParticipant?
    @Published var isMyTurn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var diceRoll: Int = 0
    @Published var canMakeMove: Bool = false

    private var raceId: String?

    init() {
        // Инициализация с пустыми данными для preview
    }

    func loadRace(_ race: Race) {
        self.race = race
        self.raceId = race.id
        self.participants = race.participants ?? []

        // Находим текущего пользователя среди участников
        if let currentUserId = trpcService.currentUser?.id {
            currentUserParticipant = participants.first { $0.userId == currentUserId }
        }

        generateRaceCells()
        updateGameState()
    }

    private func generateRaceCells() {
        guard let race = race else { return }

        raceCells = (0..<race.road.length).map { position in
            let cellType: RaceCellData.CellType
            if let roadCell = race.road.cells?.first(where: { $0.position == position }) {
                switch roadCell.cellType {
                case .normal: cellType = .normal
                case .boost: cellType = .boost
                case .obstacle: cellType = .obstacle
                case .bonus: cellType = .bonus
                case .finish: cellType = .finish
                }
            } else {
                cellType = position == race.road.length - 1 ? .finish : .normal
            }

            // Находим участников на этой позиции
            let participantsOnPosition = participants.compactMap {
                participant -> ParticipantPosition? in
                guard participant.currentPosition == position else { return nil }

                return ParticipantPosition(
                    participantId: participant.id,
                    userId: participant.userId,
                    userName: participant.user.name ?? participant.user.username ?? "Неизвестно",
                    avatarUrl: participant.user.avatarUrl,
                    isCurrentUser: participant.userId == trpcService.currentUser?.id
                )
            }

            return RaceCellData(
                position: position,
                isActive: participantsOnPosition.contains { $0.isCurrentUser },
                type: cellType,
                participants: participantsOnPosition
            )
        }
    }

    private func updateGameState() {
        guard let race = race else { return }

        // Все участники могут делать ход одновременно, если скачка активна
        canMakeMove =
            race.status == .running && currentUserParticipant != nil
            && !(currentUserParticipant?.isFinished ?? true)

        // Определяем, очередь ли текущего пользователя (упрощенная логика)
        isMyTurn = canMakeMove
    }

    func makeMove() {
        guard canMakeMove, let raceId = raceId else { return }

        isLoading = true
        errorMessage = nil

        // Генерируем случайный бросок кубика (1-6) для всех участников
        let diceRoll = Int.random(in: 1...6)
        self.diceRoll = diceRoll

        let request: [String: Any] = [
            "raceId": raceId,
            "diceRoll": diceRoll,
        ]

        Task {
            do {
                let response: MakeMoveResponse = try await trpcService.executePOST(
                    endpoint: "race.makeMove",
                    body: request
                )

                await MainActor.run {
                    // Обновляем данные после хода
                    self.refreshRace()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка хода: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func refreshRace() {
        guard let raceId = raceId else { return }

        Task {
            do {
                let response: Race = try await trpcService.executeGET(
                    endpoint: "race.getRaceById",
                    input: ["id": raceId, "includeParticipants": true]
                )

                await MainActor.run {
                    self.loadRace(response)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка обновления: \(error.localizedDescription)"
                }
            }
        }
    }
}
