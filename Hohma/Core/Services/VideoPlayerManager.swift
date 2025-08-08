//
//  VideoPlayerManager.swift
//  Hohma
//
//  Created by Artem Vydro on 03.08.2025.
//
import AVFoundation
import SwiftUI

final class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    private var cache: [String: AVPlayer] = [:]
    private var observers: [String: NSObjectProtocol] = [:]
    private var appLifecycleObservers: [NSObjectProtocol] = []

    init() {
        setupAudioSession()
        setupAppLifecycleObservers()
    }

    deinit {
        removeAllObservers()
        removeAppLifecycleObservers()
    }

    private func setupAudioSession() {
        #if os(iOS)
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                print("❌ Ошибка настройки аудиосессии: \(error)")
            }
        #elseif os(macOS)
            // На macOS аудиосессия настраивается автоматически
            // Но можно добавить дополнительные настройки если нужно
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

            appLifecycleObservers.append(willResignObserver)
            appLifecycleObservers.append(didBecomeObserver)

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

            appLifecycleObservers.append(willResignObserver)
            appLifecycleObservers.append(didBecomeObserver)
        #endif
    }

    private func removeAppLifecycleObservers() {
        for observer in appLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appLifecycleObservers.removeAll()
    }

    func pauseAllPlayers() {
        for (_, player) in cache {
            if player.timeControlStatus == .playing {
                player.pause()
            }
        }
    }

    func resumeAllPlayers() {
        for (_, player) in cache {
            if player.timeControlStatus == .paused {
                player.play()
            }
        }
    }

    private func removeAllObservers() {
        for (_, observer) in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func removeObserver(for key: String) {
        if let observer = observers[key] {
            NotificationCenter.default.removeObserver(observer)
            observers.removeValue(forKey: key)
        }
    }

    func player(resourceName: String, resourceExtension: String = "mp4") -> AVPlayer? {
        let key = "\(resourceName).\(resourceExtension)"

        // Проверяем, существует ли уже плеер и он в хорошем состоянии
        if let cachedPlayer = cache[key], cachedPlayer.currentItem?.status == .readyToPlay {
            return cachedPlayer
        }

        // Если плеер существует, но в плохом состоянии, удаляем его
        if let cachedPlayer = cache[key] {
            removeObserver(for: key)
            cachedPlayer.pause()
            cache.removeValue(forKey: key)
        }

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            print("❌ Видео не найдено: \(resourceName).\(resourceExtension)")
            return nil
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        // Создаем observer для зацикливания видео
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        observers[key] = observer
        player.play()
        cache[key] = player
        return player
    }

    func player(url: URL) -> AVPlayer {
        let key = url.absoluteString

        // Проверяем, существует ли уже плеер и он в хорошем состоянии
        if let cachedPlayer = cache[key], cachedPlayer.currentItem?.status == .readyToPlay {
            return cachedPlayer
        }

        // Если плеер существует, но в плохом состоянии, удаляем его
        if let cachedPlayer = cache[key] {
            removeObserver(for: key)
            cachedPlayer.pause()
            cache.removeValue(forKey: key)
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        // Создаем observer для зацикливания видео
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        observers[key] = observer
        player.play()
        cache[key] = player
        return player
    }

    func clearCache() {
        for (_, player) in cache {
            player.pause()
        }
        cache.removeAll()
        removeAllObservers()
    }

    func removePlayer(for key: String) {
        if let player = cache[key] {
            player.pause()
            removeObserver(for: key)
            cache.removeValue(forKey: key)
        }
    }
}
