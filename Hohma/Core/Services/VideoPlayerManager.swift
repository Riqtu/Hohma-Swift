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
        var isReady: Bool = false
        var isLoading: Bool = false
        var lastUsed: Date = Date()
        var observers: [NSObjectProtocol] = []
        private var cancellables = Set<AnyCancellable>()
        var restartCount: Int = 0

        init(player: AVPlayer) {
            self.player = player
            setupObservers()
        }

        deinit {
            cleanupObservers()
        }

        private func setupObservers() {
            // Observer для готовности к воспроизведению
            player.currentItem?.publisher(for: \.status)
                .sink { [weak self] status in
                    DispatchQueue.main.async {
                        print("🎬 CachedPlayer: Статус изменился на \(status.rawValue)")

                        switch status {
                        case .readyToPlay:
                            self?.isReady = true
                            self?.isLoading = false
                            print("✅ CachedPlayer: Плеер готов к воспроизведению")

                            // Дополнительная диагностика
                            if let player = self?.player {
                                print(
                                    "🎬 CachedPlayer: currentTime: \(player.currentTime().seconds)"
                                )
                                print(
                                    "🎬 CachedPlayer: duration: \(player.currentItem?.duration.seconds ?? 0)"
                                )
                                print("🎬 CachedPlayer: isPlaying: \(player.rate > 0)")
                            }

                        case .failed:
                            self?.isReady = false
                            self?.isLoading = false
                            print(
                                "❌ CachedPlayer: Ошибка загрузки плеера: \(self?.player.currentItem?.error?.localizedDescription ?? "неизвестная ошибка")"
                            )

                        case .unknown:
                            self?.isReady = false
                            self?.isLoading = true
                            print("🔄 CachedPlayer: Плеер загружается...")

                        @unknown default:
                            self?.isReady = false
                            self?.isLoading = false
                            print("❓ CachedPlayer: Неизвестный статус плеера: \(status.rawValue)")
                        }
                    }
                }
                .store(in: &cancellables)

            // Observer для окончания видео
            NotificationCenter.default.publisher(
                for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem
            )
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    // Ограничиваем количество перезапусков для внешних URL
                    if let self = self {
                        self.restartCount += 1

                        // Для внешних URL ограничиваем перезапуски до 2 раз
                        let maxRestarts = self.player.currentItem?.asset is AVURLAsset ? 2 : 10

                        if self.restartCount <= maxRestarts {
                            print(
                                "🎬 CachedPlayer: Видео закончилось, перезапускаем (попытка \(self.restartCount)/\(maxRestarts))"
                            )

                            // Добавляем задержку перед перезапуском для внешних URL
                            let delay = self.player.currentItem?.asset is AVURLAsset ? 1.0 : 0.1

                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.player.seek(to: .zero)
                                self.player.play()
                            }
                        } else {
                            print("⏹️ CachedPlayer: Достигнут лимит перезапусков, останавливаем")
                            self.player.pause()

                            // Для внешних URL после достижения лимита перезапусков
                            // помечаем плеер как не готовый, чтобы он был заменен
                            if self.player.currentItem?.asset is AVURLAsset {
                                self.isReady = false
                                print(
                                    "🔄 CachedPlayer: Внешний URL помечен как не готовый для замены")
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)

            // Observer для приостановки
            player.publisher(for: \.rate)
                .sink { rate in
                    DispatchQueue.main.async {
                        if rate == 0 {
                            print("🎬 CachedPlayer: Плеер приостановлен")
                        }
                    }
                }
                .store(in: &cancellables)
        }

        private func cleanupObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
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
        #if os(iOS)
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                print("❌ Ошибка настройки аудиосессии: \(error)")
            }
        #endif
    }

    private func setupAppLifecycleObservers() {
        #if os(iOS)
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

        #elseif os(macOS)
            let willResignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pauseAllPlayers()
            }

            let didBecomeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resumeAllPlayers()
            }

            appLifecycleObservers.append(contentsOf: [willResignObserver, didBecomeObserver])
        #endif
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

        print("🎬 VideoPlayerManager: Запрос плеера для \(key)")

        // Проверяем кэш
        if let cachedPlayer = cache[key] {
            cachedPlayer.updateLastUsed()
            print(
                "🎬 VideoPlayerManager: Найден кэшированный плеер для \(key), готов: \(cachedPlayer.isReady), загружается: \(cachedPlayer.isLoading)"
            )

            // Если плеер готов, возвращаем его
            if cachedPlayer.isReady {
                print("✅ VideoPlayerManager: Возвращаем готовый плеер для \(key)")
                return cachedPlayer.player
            }

            // Если плеер загружается, ждем
            if cachedPlayer.isLoading {
                print("🔄 VideoPlayerManager: Плеер \(key) все еще загружается, возвращаем его")
                return cachedPlayer.player
            }

            // Если плеер в плохом состоянии (failed), удаляем его
            if cachedPlayer.player.currentItem?.status == .failed {
                print("❌ VideoPlayerManager: Удаляем плохой плеер для \(key)")
                removePlayer(for: key)
            } else {
                // Если плеер в unknown состоянии, даем ему время
                print("⏳ VideoPlayerManager: Плеер \(key) в unknown состоянии, даем время")
                return cachedPlayer.player
            }
        }

        // Создаем новый плеер
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            print(
                "❌ VideoPlayerManager: Видео не найдено в Bundle: \(resourceName).\(resourceExtension)"
            )
            print("📁 Доступные ресурсы в Bundle:")
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

        print("✅ VideoPlayerManager: Создаем новый плеер для \(url)")
        return createPlayer(for: url, key: key)
    }

    func player(url: URL) -> AVPlayer {
        let key = url.absoluteString
        print("🎬 VideoPlayerManager: Запрос плеера для URL: \(key)")

        // Проверяем кэш
        if let cachedPlayer = cache[key] {
            print(
                "🎬 VideoPlayerManager: Найден кэшированный плеер для URL, готов: \(cachedPlayer.isReady)"
            )

            // Если плеер готов, возвращаем его
            if cachedPlayer.isReady {
                print("✅ VideoPlayerManager: Возвращаем готовый кэшированный плеер")
                cachedPlayer.lastUsed = Date()
                return cachedPlayer.player
            }

            // Если плеер загружается, даем ему еще время
            let timeSinceCreation = Date().timeIntervalSince(cachedPlayer.lastUsed)
            let maxWaitTime = url.scheme == "http" || url.scheme == "https" ? 5.0 : 10.0

            if timeSinceCreation < maxWaitTime {
                print(
                    "🔄 VideoPlayerManager: Плеер еще загружается, даем время (\(Int(maxWaitTime - timeSinceCreation))с)"
                )
                cachedPlayer.lastUsed = Date()
                return cachedPlayer.player
            }

            // Если плеер не готов слишком долго, удаляем его
            print("⏰ VideoPlayerManager: Плеер не готов слишком долго, удаляем")
            cache.removeValue(forKey: key)
        }

        // Создаем новый плеер
        print("✅ VideoPlayerManager: Создаем новый плеер для URL: \(key)")
        return createPlayer(for: url, key: key)
    }

    // MARK: - Private Methods
    private func createPlayer(for url: URL, key: String) -> AVPlayer {
        print("🎬 VideoPlayerManager: Создание плеера для \(url)")

        let player: AVPlayer

        // Проверяем, является ли URL внешним
        if url.scheme == "http" || url.scheme == "https" {
            // Для внешних URL используем потоковое воспроизведение
            print("🎬 VideoPlayerManager: Внешний URL, настраиваем потоковое воспроизведение")

            // Создаем AVPlayerItem с настройками для потокового воспроизведения
            let playerItem = AVPlayerItem(url: url)

            // Настройки для быстрого старта без полной загрузки
            playerItem.preferredForwardBufferDuration = 5.0  // Увеличиваем буфер для стабильности
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

            // Дополнительные настройки для стабильности
            playerItem.preferredPeakBitRate = 0  // Автоматический выбор битрейта

            // Создаем плеер с настроенным item
            player = AVPlayer(playerItem: playerItem)

            // Дополнительные настройки для внешних URL
            player.automaticallyWaitsToMinimizeStalling = true  // Включаем для стабильности
            player.allowsExternalPlayback = false

        } else {
            // Для локальных файлов используем обычный подход
            player = AVPlayer(url: url)
            player.automaticallyWaitsToMinimizeStalling = false
        }

        player.isMuted = true
        player.actionAtItemEnd = .none

        print(
            "🎬 VideoPlayerManager: Плеер создан, currentItem: \(player.currentItem?.description ?? "nil")"
        )

        // Создаем cached player
        let cachedPlayer = CachedPlayer(player: player)
        cache[key] = cachedPlayer

        // Начинаем воспроизведение
        print("🎬 VideoPlayerManager: Запускаем воспроизведение")
        player.play()

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
            if cachedPlayer.player.timeControlStatus == .paused && cachedPlayer.isReady {
                cachedPlayer.player.play()
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
