import AVFoundation
import SwiftUI

@MainActor
final class WheelCardViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var uniqueUsers: [AuthUser] = []
    @Published var winnerUser: AuthUser?

    let cardData: WheelWithRelations

    init(cardData: WheelWithRelations) {
        self.cardData = cardData
        setupPlayer()
        processUsers()
    }

    private func setupPlayer() {
        guard let urlString = cardData.theme?.backgroundVideoURL,
            let url = URL(string: urlString)
        else { return }

        player = VideoPlayerManager.shared.player(url: url)
    }

    private func processUsers() {
        // Получаем уникальных пользователей по ID
        var uniqueUsersDict: [String: AuthUser] = [:]

        for sector in cardData.sectors {
            if let user = sector.user {
                uniqueUsersDict[user.id] = user
            }
        }

        uniqueUsers = Array(uniqueUsersDict.values)

        // Находим победителя
        if let winnerSector = cardData.sectors.first(where: { $0.winner }) {
            winnerUser = winnerSector.user
        }
    }

    var hasWinner: Bool {
        cardData.sectors.contains(where: { $0.winner })
    }

    var hasParticipants: Bool {
        !cardData.sectors.isEmpty
    }

    var participantsCount: Int {
        uniqueUsers.count
    }

    var additionalParticipantsCount: Int {
        max(0, participantsCount - 5)
    }

    var shouldShowAdditionalCount: Bool {
        participantsCount > 5
    }
}
