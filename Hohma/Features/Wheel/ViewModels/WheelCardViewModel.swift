import AVFoundation
import SwiftUI

@MainActor
final class WheelCardViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var uniqueUsers: [AuthUser] = []
    @Published var winnerUser: AuthUser?

    private let videoManager = VideoPlayerManager.shared
    private var playerKey: String?

    let cardData: WheelWithRelations

    init(cardData: WheelWithRelations) {
        self.cardData = cardData
        processUsers()
    }

    deinit {
        // Очищаем ресурсы синхронно в deinit
        // Не можем обращаться к @Published свойствам в deinit из-за MainActor
        // Очистка произойдет автоматически при уничтожении объекта
    }

    private func cleanupPlayer() {
        if let player = player {
            player.pause()
            self.player = nil
        }
        if let key = playerKey {
            videoManager.removePlayer(for: key)
            playerKey = nil
        }
    }

    private func setupPlayer() {
        guard let urlString = cardData.theme?.backgroundVideoURL,
            let url = URL(string: urlString)
        else { return }

        // Очищаем предыдущий плеер
        cleanupPlayer()

        // Создаем новый плеер
        player = videoManager.player(url: url)
        playerKey = url.absoluteString
    }

    func resumePlayer() {
        if player == nil {
            setupPlayer()
        } else {
            player?.play()
        }
    }

    func pausePlayer() {
        player?.pause()
    }

    func ensurePlayerExists() {
        if player == nil {
            setupPlayer()
        }
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
