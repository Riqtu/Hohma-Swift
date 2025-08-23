import AVFoundation
import Combine  // Added for Combine publishers
import SwiftUI

@MainActor
final class WheelCardViewModel: ObservableObject {
    // MARK: - Properties
    @Published var cardData: WheelWithRelations
    @Published var isVideoReady: Bool = false
    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false
    @Published var uniqueUsers: [AuthUser] = []
    @Published var winnerUser: AuthUser?

    // Новый потоковый плеер
    private var streamPlayer: StreamPlayer?
    private var streamVideoService = StreamVideoService.shared

    // MARK: - Initialization

    init(cardData: WheelWithRelations) {
        self.cardData = cardData
        processUsers()
        setupPlayer()
    }

    deinit {
        // Не можем вызывать MainActor методы в deinit
        // Очистка произойдет автоматически при уничтожении объекта
    }

    // MARK: - Public Methods

    func updateCardData(_ newCardData: WheelWithRelations) {
        print("🔄 WheelCardViewModel: обновляем данные для \(newCardData.name)")

        // Очищаем старый плеер перед обновлением
        cleanupPlayer()

        self.cardData = newCardData
        processUsers()
        setupPlayer()
    }

    func onAppear() {
        streamPlayer?.resume()
    }

    func onDisappear() {
        // Не останавливаем видео при исчезновении карточки
        // streamPlayer?.pause()
    }

    func onScenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            streamPlayer?.resume()
        case .inactive, .background:
            streamPlayer?.pause()
        @unknown default:
            break
        }
    }

    // MARK: - Private Methods

    private func setupPlayer() {
        print("🎬 Настраиваем плеер для \(cardData.name)")

        // Сначала пробуем внешний URL (если есть)
        if let urlString = cardData.theme?.backgroundVideoURL,
            let url = URL(string: urlString)
        {
            print("🎬 Используем внешний URL: \(urlString)")
            setupStreamPlayer(with: url)
        } else {
            print("🎬 Используем локальное видео")
            // Fallback на локальное видео только если нет внешнего URL
            setupLocalVideo()
        }
    }

    private func setupStreamPlayer(with url: URL) {
        // Получаем потоковый плеер
        streamPlayer = streamVideoService.getStreamPlayer(for: url)

        // Подписываемся на изменения состояния
        streamPlayer?.$isReady
            .sink { [weak self] isReady in
                DispatchQueue.main.async {
                    self?.isVideoReady = isReady
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        streamPlayer?.$isLoading
            .sink { [weak self] isLoading in
                DispatchQueue.main.async {
                    self?.isLoading = isLoading
                }
            }
            .store(in: &cancellables)

        streamPlayer?.$hasError
            .sink { [weak self] hasError in
                DispatchQueue.main.async {
                    self?.hasError = hasError
                    if hasError {
                        self?.fallbackToLocalVideo()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupLocalVideo() {
        // Для локального видео используем старый VideoPlayerManager
        let videoManager = VideoPlayerManager.shared
        let player = videoManager.player(resourceName: "background")

        if let player = player {
            self._player = player
            self.playerKey = "background"
            setupPlayerObserver(player)
        } else {
            hasError = true
        }
    }

    private func fallbackToLocalVideo() {
        // Очищаем потоковый плеер
        if let url = URL(string: cardData.theme?.backgroundVideoURL ?? "") {
            streamVideoService.removePlayer(for: url)
        }
        streamPlayer = nil

        // Переключаемся на локальное видео
        setupLocalVideo()
    }

    private func cleanupPlayer() {
        print("🧹 Очищаем плеер для \(cardData.name)")

        // Очищаем потоковый плеер
        if let url = URL(string: cardData.theme?.backgroundVideoURL ?? "") {
            streamVideoService.removePlayer(for: url)
        }
        streamPlayer = nil

        // Очищаем старый плеер
        playerObserver?.invalidate()
        playerObserver = nil
        _player = nil
        playerKey = nil

        // Сбрасываем состояния
        isVideoReady = false
        isLoading = true
        hasError = false
    }

    // MARK: - Legacy Support (для локального видео)

    // Эти свойства и методы используются только для локального видео
    var player: AVPlayer? { return _player }
    private var _player: AVPlayer?
    private var playerKey: String?
    private var playerObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    private func setupPlayerObserver(_ player: AVPlayer) {
        playerObserver?.invalidate()

        playerObserver = player.currentItem?.observe(\.status, options: [.new]) {
            [weak self] item, _ in
            DispatchQueue.main.async {
                self?.isVideoReady = item.status == .readyToPlay
                self?.isLoading = item.status == .unknown

                if self?.isVideoReady == true {
                    player.play()
                }
            }
        }

        if player.currentItem?.status == .readyToPlay {
            self.isVideoReady = true
            player.play()
        }
    }

    func resumePlayer() {
        if _player == nil {
            setupPlayer()
        } else if isVideoReady {
            _player?.play()
        }
    }

    func pausePlayer() {
        _player?.pause()
    }

    func ensurePlayerExists() {
        if _player == nil {
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

    // Метод для получения актуальных данных
    func getCurrentCardData() -> WheelWithRelations {
        return cardData
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
