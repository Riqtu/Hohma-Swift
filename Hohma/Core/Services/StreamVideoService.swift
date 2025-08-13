import AVFoundation
import Combine
import SwiftUI

/// Специализированный сервис для потокового воспроизведения видео
/// Оптимизирован для внешних URL с минимальной задержкой и максимальной стабильностью
@MainActor
final class StreamVideoService: ObservableObject {
    static let shared = StreamVideoService()

    // MARK: - Properties
    private var players: [String: StreamPlayer] = [:]
    private let queue = DispatchQueue(label: "com.hohma.streamvideo", qos: .userInitiated)

    // MARK: - Public Methods

    /// Получает или создает потоковый плеер для URL
    func getStreamPlayer(for url: URL) -> StreamPlayer {
        let key = url.absoluteString

        if let existingPlayer = players[key] {
            return existingPlayer
        }

        let player = StreamPlayer(url: url)
        players[key] = player
        return player
    }

    /// Очищает все плееры
    func clearAllPlayers() {
        players.removeAll()
    }

    /// Приостанавливает все плееры
    func pauseAllPlayers() {
        players.values.forEach { $0.pause() }
    }

    /// Возобновляет все плееры
    func resumeAllPlayers() {
        players.values.forEach { $0.resume() }
    }

    /// Удаляет плеер для конкретного URL
    func removePlayer(for url: URL) {
        let key = url.absoluteString
        players.removeValue(forKey: key)
    }
}

// MARK: - StreamPlayer

/// Оптимизированный плеер для потокового воспроизведения
@MainActor
final class StreamPlayer: ObservableObject {
    // MARK: - Properties
    private let url: URL
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?

    @Published var isReady = false
    @Published var isLoading = true
    @Published var hasError = false
    @Published var errorMessage: String?

    // MARK: - Initialization

    init(url: URL) {
        self.url = url
        setupPlayer()
    }

    deinit {
        // Не можем вызывать MainActor методы в deinit
        // Очистка произойдет автоматически при уничтожении объекта
    }

    // MARK: - Public Methods

    var avPlayer: AVPlayer? {
        return player
    }

    func play() {
        guard let player = player, isReady else { return }
        print("▶️ StreamPlayer: Запускаем воспроизведение")
        player.play()
    }

    func pause() {
        guard let player = player else { return }
        // Не останавливаем видео полностью, только приостанавливаем
        player.pause()
    }

    func resume() {
        guard let player = player, isReady else { return }
        player.play()
    }

    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        cancellables.removeAll()
        player?.pause()
        player = nil
        playerLayer = nil
    }

    // MARK: - Private Methods

    private func setupPlayer() {
        // Создаем AVPlayerItem с оптимизированными настройками для потокового воспроизведения
        let playerItem = createOptimizedPlayerItem()

        // Создаем плеер
        player = AVPlayer(playerItem: playerItem)

        // Настраиваем плеер для потокового воспроизведения
        configurePlayerForStreaming()

        // Настраиваем observers
        setupObservers()

        // Запускаем воспроизведение сразу после готовности
        startPlaybackWhenReady()
    }

    private func createOptimizedPlayerItem() -> AVPlayerItem {
        let playerItem = AVPlayerItem(url: url)

        // Оптимизированные настройки для потокового воспроизведения
        playerItem.preferredForwardBufferDuration = 2.0  // Минимальный буфер для быстрого старта
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        playerItem.preferredPeakBitRate = 0  // Автоматический выбор битрейта

        // Дополнительные настройки для стабильности
        playerItem.automaticallyPreservesTimeOffsetFromLive = false

        return playerItem
    }

    private func configurePlayerForStreaming() {
        guard let player = player else { return }

        // Отключаем автоматическое ожидание для потокового воспроизведения
        player.automaticallyWaitsToMinimizeStalling = false

        // Устанавливаем скорость воспроизведения
        player.rate = 1.0
    }

    private func setupObservers() {
        guard let player = player else { return }

        // Observer для статуса готовности
        player.currentItem?.publisher(for: \.status)
            .sink { [weak self] status in
                DispatchQueue.main.async {
                    self?.handleStatusChange(status)
                }
            }
            .store(in: &cancellables)

        // Observer для ошибок
        player.currentItem?.publisher(for: \.error)
            .sink { [weak self] error in
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)

        // Observer для окончания видео
        NotificationCenter.default.publisher(
            for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem
        )
        .sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleVideoEnd()
            }
        }
        .store(in: &cancellables)

        // Observer для буферизации
        player.currentItem?.publisher(for: \.loadedTimeRanges)
            .sink { [weak self] ranges in
                DispatchQueue.main.async {
                    self?.handleBufferUpdate(ranges)
                }
            }
            .store(in: &cancellables)
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            isLoading = false
            isReady = true
            hasError = false
            errorMessage = nil

        case .failed:
            isLoading = false
            isReady = false
            hasError = true
            errorMessage = player?.currentItem?.error?.localizedDescription ?? "Неизвестная ошибка"

        case .unknown:
            isLoading = true
            isReady = false
            hasError = false
            errorMessage = nil

        @unknown default:
            isLoading = false
            isReady = false
            hasError = true
            errorMessage = "Неизвестный статус плеера"
        }
    }

    private func handleError(_ error: Error?) {
        if let error = error {
            hasError = true
            errorMessage = error.localizedDescription
        }
    }

    private func handleVideoEnd() {
        // Для потокового видео просто перезапускаем без задержки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }

    private func handleBufferUpdate(_ ranges: [NSValue]) {
        // Обработка обновления буфера (оставлено для будущего использования)
    }

    private func startPlaybackWhenReady() {
        // Запускаем воспроизведение как только плеер будет готов
        $isReady
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                self?.play()
            }
            .store(in: &cancellables)
    }
}
