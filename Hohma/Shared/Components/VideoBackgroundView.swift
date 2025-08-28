import AVFoundation
import SwiftUI

/// Видео фон компонент с поддержкой управления звуком
///
/// Пример использования:
/// ```swift
/// // Без звука (не прерывает Spotify/Apple Music)
/// VideoBackgroundView(player: player, isMuted: true)
///
/// // Со звуком (может прерывать другие приложения)
/// VideoBackgroundView(player: player, isMuted: false)
/// ```
#if os(iOS)
    import UIKit

    class VideoPlayerView: UIView {
        let playerLayer: AVPlayerLayer
        private var timeObserver: Any?
        private var playerItemObserver: NSKeyValueObservation?
        private var isVisible: Bool = true
        private var isLoading: Bool = false
        private var isExternalURL: Bool = false
        private var isMuted: Bool = true

        init(player: AVPlayer, isMuted: Bool = true) {
            self.playerLayer = AVPlayerLayer(player: player)
            self.isMuted = isMuted
            super.init(frame: .zero)

            // Определяем, является ли это внешним URL
            if let urlAsset = player.currentItem?.asset as? AVURLAsset {
                self.isExternalURL = urlAsset.url.scheme == "http" || urlAsset.url.scheme == "https"
            }

            // Настраиваем аудиосессию для работы с другими приложениями
            setupAudioSession()

            // Важно: настраиваем layer правильно
            self.playerLayer.videoGravity = .resizeAspectFill
            self.playerLayer.backgroundColor = UIColor.clear.cgColor
            self.playerLayer.opacity = 1.0

            // Добавляем layer к view
            self.layer.addSublayer(playerLayer)

            // Принудительно устанавливаем frame
            DispatchQueue.main.async {
                self.playerLayer.frame = self.bounds
            }

            setupPlayerObservers()

            // Принудительно запускаем воспроизведение
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.currentItem?.status == .readyToPlay {
                    player.play()
                }
            }
        }

        required init?(coder: NSCoder) { fatalError() }

        deinit {
            cleanupObservers()
        }

        private func cleanupObservers() {
            if let timeObserver = timeObserver {
                playerLayer.player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            playerItemObserver?.invalidate()
            playerItemObserver = nil
        }

        private func setupPlayerObservers() {
            // Observer для отслеживания состояния playerItem
            playerItemObserver = playerLayer.player?.currentItem?.observe(\.status, options: [.new])
            {
                [weak self] item, _ in
                DispatchQueue.main.async {
                    switch item.status {
                    case .readyToPlay:
                        self?.isLoading = false
                        self?.playerLayer.player?.play()

                        // Принудительно обновляем layout
                        self?.setNeedsLayout()
                        self?.layoutSubviews()
                    case .failed:
                        self?.isLoading = false
                        // Обработка ошибок для внешних URL
                        if let error = item.error {
                            print("❌ Ошибка воспроизведения видео: \(error)")
                            // Для внешних URL можно попробовать перезагрузить
                            if let self = self, self.isExternalURL {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    self.retryLoading()
                                }
                            }
                        }
                    case .unknown:
                        self?.isLoading = true
                        break
                    @unknown default:
                        self?.isLoading = false
                        break
                    }
                }
            }

            // Observer для зацикливания
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerLayer.player?.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.playerLayer.player?.seek(to: .zero)
                self?.playerLayer.player?.play()
            }

            // Проверяем текущий статус
            if let player = playerLayer.player, player.currentItem?.status == .readyToPlay {
                player.play()
            }
        }

        private func setupAudioSession() {
            #if os(iOS)
                do {
                    let audioSession = AVAudioSession.sharedInstance()

                    if isMuted {
                        // Для фонового видео без звука - не прерываем другие приложения
                        try audioSession.setCategory(
                            .playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                    } else {
                        // Для видео со звуком - стандартная настройка
                        try audioSession.setCategory(.playback, mode: .default, options: [])
                    }

                    try audioSession.setActive(true)
                } catch {
                    print("❌ Ошибка настройки аудиосессии: \(error)")
                }
            #endif
        }

        private func retryLoading() {
            guard let urlAsset = playerLayer.player?.currentItem?.asset as? AVURLAsset else {
                return
            }
            let newPlayerItem = AVPlayerItem(url: urlAsset.url)
            playerLayer.player?.replaceCurrentItem(with: newPlayerItem)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
            playerLayer.setNeedsDisplay()
        }

        func setVisible(_ visible: Bool) {
            isVisible = visible
            if visible {
                playerLayer.player?.play()
            } else {
                playerLayer.player?.pause()
            }
        }
    }

    struct VideoBackgroundView: UIViewRepresentable {
        let player: AVPlayer
        let isMuted: Bool

        init(player: AVPlayer, isMuted: Bool = true) {
            self.player = player
            self.isMuted = isMuted
        }

        func makeUIView(context: Context) -> VideoPlayerView {
            let view = VideoPlayerView(player: player, isMuted: isMuted)
            return view
        }

        func updateUIView(_ uiView: VideoPlayerView, context: Context) {
            // Обновляем плеер если нужно
            if uiView.playerLayer.player !== player {
                uiView.playerLayer.player = player

                // Принудительно запускаем воспроизведение
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if player.currentItem?.status == .readyToPlay {
                        player.play()
                    }
                }
            }

            // Принудительно обновляем layout
            DispatchQueue.main.async {
                uiView.setNeedsLayout()
                uiView.layoutSubviews()
            }
        }
    }

#elseif os(macOS)
    import AppKit

    class VideoPlayerView: NSView {
        let playerLayer: AVPlayerLayer
        private var playerItemObserver: NSKeyValueObservation?
        private var isVisible: Bool = true
        private var isLoading: Bool = false
        private var isExternalURL: Bool = false
        private var isMuted: Bool = true

        init(player: AVPlayer, isMuted: Bool = true) {
            self.playerLayer = AVPlayerLayer(player: player)
            self.isMuted = isMuted
            super.init(frame: .zero)

            // Определяем, является ли это внешним URL
            if let urlAsset = player.currentItem?.asset as? AVURLAsset {
                self.isExternalURL = urlAsset.url.scheme == "http" || urlAsset.url.scheme == "https"
            }

            // Настраиваем аудиосессию для работы с другими приложениями
            setupAudioSession()

            self.wantsLayer = true
            self.layer = CALayer()

            // Важно: настраиваем layer правильно
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = NSColor.clear.cgColor
            playerLayer.opacity = 1.0
            playerLayer.frame = bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

            layer?.addSublayer(playerLayer)

            setupPlayerObservers()

            // Принудительно запускаем воспроизведение
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.currentItem?.status == .readyToPlay {
                    player.play()
                }
            }
        }

        required init?(coder: NSCoder) { fatalError() }

        deinit {
            cleanupObservers()
        }

        private func cleanupObservers() {
            playerItemObserver?.invalidate()
            playerItemObserver = nil
        }

        private func setupPlayerObservers() {
            // Observer для отслеживания состояния playerItem
            playerItemObserver = playerLayer.player?.currentItem?.observe(\.status, options: [.new])
            {
                [weak self] item, _ in
                DispatchQueue.main.async {
                    if item.status == .readyToPlay {
                        self?.playerLayer.player?.play()

                        // Принудительно обновляем layout
                        self?.layout()
                    }
                }
            }

            // Observer для зацикливания
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerLayer.player?.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.playerLayer.player?.seek(to: .zero)
                self?.playerLayer.player?.play()
            }

            // Проверяем текущий статус
            if let player = playerLayer.player, player.currentItem?.status == .readyToPlay {
                player.play()
            }
        }

        private func setupAudioSession() {
            #if os(macOS)
                // На macOS аудиосессия настраивается автоматически
                // Просто устанавливаем muted состояние плеера
                playerLayer.player?.isMuted = isMuted
            #endif
        }

        private func retryLoading() {
            guard let urlAsset = playerLayer.player?.currentItem?.asset as? AVURLAsset else {
                return
            }
            let newPlayerItem = AVPlayerItem(url: urlAsset.url)
            playerLayer.player?.replaceCurrentItem(with: newPlayerItem)
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
            playerLayer.setNeedsDisplay()
        }

        func setVisible(_ visible: Bool) {
            isVisible = visible
            if visible {
                playerLayer.player?.play()
            } else {
                playerLayer.player?.pause()
            }
        }
    }

    struct VideoBackgroundView: NSViewRepresentable {
        let player: AVPlayer
        let isMuted: Bool

        init(player: AVPlayer, isMuted: Bool = true) {
            self.player = player
            self.isMuted = isMuted
        }

        func makeNSView(context: Context) -> VideoPlayerView {
            let view = VideoPlayerView(player: player, isMuted: isMuted)
            return view
        }

        func updateNSView(_ nsView: VideoPlayerView, context: Context) {
            // Обновляем плеер если нужно
            if nsView.playerLayer.player !== player {
                nsView.playerLayer.player = player

                // Принудительно запускаем воспроизведение
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if player.currentItem?.status == .readyToPlay {
                        player.play()
                    }
                }
            }

            // Принудительно обновляем layout
            DispatchQueue.main.async {
                nsView.layout()
            }
        }
    }
#endif
