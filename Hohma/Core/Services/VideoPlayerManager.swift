//
//  VideoPlayerManager.swift
//  Hohma
//
//  Created by Artem Vydro on 03.08.2025.
//
import AVFoundation
import Combine
import SwiftUI

final class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()

    // MARK: - Properties
    private var cache: [String: CachedPlayer] = [:]
    private var appLifecycleObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cached Player Structure
    private class CachedPlayer {
        let player: AVPlayer
        var looper: AVPlayerLooper? // Для бесконечного зацикливания локальных видео
        var endTimeObserver: NSObjectProtocol? // Для зацикливания внешних URL
        var isReady: Bool = false
        var isLoading: Bool = false
        var lastUsed: Date = Date()
        private var cancellables = Set<AnyCancellable>()
        private var isLocalFile: Bool = false

        init(player: AVPlayer, isLocalFile: Bool) {
            self.player = player
            self.isLocalFile = isLocalFile
            setupObservers()
        }

        deinit {
            cleanup()
        }

        private func setupObservers() {
            // Observer для готовности к воспроизведению
            player.currentItem?.publisher(for: \.status)
                .sink { [weak self] status in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        switch status {
                        case .readyToPlay:
                            self.isReady = true
                            self.isLoading = false
                            // Автоматически запускаем воспроизведение когда готово
                            // Проверяем что не играет и не ждет, чтобы избежать конфликтов
                            let timeControlStatus = self.player.timeControlStatus
                            if timeControlStatus != .playing && timeControlStatus != .waitingToPlayAtSpecifiedRate {
                                self.player.play()
                            }
                        case .failed:
                            self.isReady = false
                            self.isLoading = false
                        case .unknown:
                            self.isReady = false
                            self.isLoading = true
                        @unknown default:
                            self.isReady = false
                            self.isLoading = false
                        }
                    }
                }
                .store(in: &cancellables)
        }

        func setupEndTimeObserver() {
            guard let playerItem = player.currentItem else { return }
            endTimeObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                self.player.seek(to: .zero)
                self.player.play()
            }
        }

        private func cleanup() {
            // AVPlayerLooper автоматически останавливается при деаллокации
            looper = nil
            if let observer = endTimeObserver {
                NotificationCenter.default.removeObserver(observer)
                endTimeObserver = nil
            }
            cancellables.removeAll()
        }

        func updateLastUsed() {
            lastUsed = Date()
        }
    }

    // MARK: - Initialization
    private init() {
        setupAudioSession()
        setupAppLifecycleObservers()
        setupMemoryWarningObserver()
        startCacheCleanupTimer()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup Methods
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Настраиваем для работы с другими приложениями (Spotify, Apple Music и т.д.)
            try audioSession.setCategory(
                .playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Ошибка настройки аудиосессии: \(error)")
        }
    }

    private func setupAppLifecycleObservers() {
        let willResignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseAllPlayers()
        }

        let didBecomeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumeAllPlayers()
        }

        let didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pauseAllPlayers()
        }

        appLifecycleObservers.append(contentsOf: [
            willResignObserver, didBecomeObserver, didEnterBackgroundObserver,
        ])
    }

    private func setupMemoryWarningObserver() {
        #if os(iOS)
            let memoryWarningObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.clearUnusedCache()
            }
            appLifecycleObservers.append(memoryWarningObserver)
        #endif
    }

    private func startCacheCleanupTimer() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.clearUnusedCache()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    func player(resourceName: String, resourceExtension: String = "mp4") -> AVPlayer? {
        let key = "\(resourceName).\(resourceExtension)"

        // Проверяем кэш
        if let cachedPlayer = cache[key] {
            cachedPlayer.updateLastUsed()
            return cachedPlayer.player
        }

        // Создаем новый плеер
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    contents.filter { $0.hasSuffix(".mp4") }.forEach { print("   - \($0)") }
                } catch {
                    print("❌ Ошибка чтения ресурсов: \(error)")
                }
            }
            return nil
        }

        return createPlayer(for: url, key: key, isLocalFile: true)
    }

    func player(url: URL) -> AVPlayer {
        let key = url.absoluteString

        // Проверяем кэш
        if let cachedPlayer = cache[key] {
            cachedPlayer.updateLastUsed()
            return cachedPlayer.player
        }

        // Создаем новый плеер
        let isLocalFile = url.scheme != "http" && url.scheme != "https"
        return createPlayer(for: url, key: key, isLocalFile: isLocalFile)
    }

    // MARK: - Private Methods
    private func createPlayer(for url: URL, key: String, isLocalFile: Bool) -> AVPlayer {
        let player: AVPlayer
        var looper: AVPlayerLooper?

        if isLocalFile {
            // Для локальных файлов используем AVQueuePlayer + AVPlayerLooper для бесконечного зацикливания
            let playerItem = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            
            // Создаем looper для бесконечного зацикливания
            looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            
            player = queuePlayer
            player.automaticallyWaitsToMinimizeStalling = false
        } else {
            // Для внешних URL используем потоковое воспроизведение
            let playerItem = AVPlayerItem(url: url)
            playerItem.preferredForwardBufferDuration = 5.0
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            playerItem.preferredPeakBitRate = 0
            
            player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            player.allowsExternalPlayback = false
        }

        player.isMuted = true
        player.actionAtItemEnd = .none

        // Создаем cached player
        let cachedPlayer = CachedPlayer(player: player, isLocalFile: isLocalFile)
        cachedPlayer.looper = looper
        
        // Для внешних URL настраиваем observer для зацикливания
        if !isLocalFile {
            cachedPlayer.setupEndTimeObserver()
        }
        
        cache[key] = cachedPlayer

        // Начинаем воспроизведение когда готово
        if let playerItem = player.currentItem {
            if playerItem.status == .readyToPlay {
                player.play()
            }
        } else {
            // Если еще не готов, запустится автоматически через observer
            player.play()
        }

        return player
    }

    func pauseAllPlayers() {
        for (_, cachedPlayer) in cache {
            if cachedPlayer.player.timeControlStatus == .playing {
                cachedPlayer.player.pause()
            }
        }
    }

    func resumeAllPlayers() {
        for (_, cachedPlayer) in cache {
            let player = cachedPlayer.player
            let timeControlStatus = player.timeControlStatus
            
            // Запускаем только если не играет и не ждет
            // Это предотвращает конфликты и множественные вызовы play()
            if timeControlStatus != .playing && timeControlStatus != .waitingToPlayAtSpecifiedRate {
                // Вызываем play() независимо от статуса - AVPlayer сам решит когда начать
                // Если readyToPlay - начнется сразу, если еще загружается - начнется когда будет готово
                player.play()
            }
        }
    }

    private func clearUnusedCache() {
        let now = Date()
        let unusedThreshold: TimeInterval = 300  // 5 минут

        let keysToRemove = cache.compactMap { key, cachedPlayer in
            now.timeIntervalSince(cachedPlayer.lastUsed) > unusedThreshold ? key : nil
        }

        for key in keysToRemove {
            removePlayer(for: key)
        }

        // Если кэш все еще слишком большой, удаляем самые старые
        if cache.count > 5 {
            let sortedKeys = cache.sorted { $0.value.lastUsed < $1.value.lastUsed }
            let keysToRemove = sortedKeys.prefix(cache.count - 3).map { $0.key }

            for key in keysToRemove {
                removePlayer(for: key)
            }
        }
    }

    private func removePlayer(for key: String) {
        guard let cachedPlayer = cache[key] else { return }
        
        // AVPlayerLooper автоматически останавливается при деаллокации
        cachedPlayer.looper = nil
        cachedPlayer.player.pause()
        cache.removeValue(forKey: key)
    }

    private func cleanup() {
        // Очищаем кэш
        for (_, cachedPlayer) in cache {
            cachedPlayer.player.pause()
        }
        cache.removeAll()

        // Удаляем observers
        for observer in appLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appLifecycleObservers.removeAll()

        // Отменяем cancellables
        cancellables.removeAll()
    }

    // MARK: - Public Utility Methods
    func clearCache() {
        for (_, cachedPlayer) in cache {
            cachedPlayer.player.pause()
        }
        cache.removeAll()
    }

    func removePlayerFromCache(for key: String) {
        removePlayer(for: key)
    }

    func preloadVideo(resourceName: String, resourceExtension: String = "mp4") {
        _ = player(resourceName: resourceName, resourceExtension: resourceExtension)
    }

    func preloadVideo(url: URL) {
        _ = player(url: url)
    }
}
