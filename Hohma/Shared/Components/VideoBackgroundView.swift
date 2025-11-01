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
        private var didPlayToEndObserver: NSObjectProtocol?
        private var isVisible: Bool = true
        private var isLoading: Bool = false
        private var isExternalURL: Bool = false
        private var isMuted: Bool = true
        private var hasPlayedBefore: Bool = false

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
            startPlaybackIfReady()
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
            
            if let didPlayToEndObserver = didPlayToEndObserver {
                NotificationCenter.default.removeObserver(didPlayToEndObserver)
                self.didPlayToEndObserver = nil
            }
        }

        func setupPlayerObservers() {
            // Очищаем только observer'ы, которые будем пересоздавать
            if let timeObserver = timeObserver {
                playerLayer.player?.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            playerItemObserver?.invalidate()
            playerItemObserver = nil
            
            if let didPlayToEndObserver = didPlayToEndObserver {
                NotificationCenter.default.removeObserver(didPlayToEndObserver)
                self.didPlayToEndObserver = nil
            }
            
            // Observer для отслеживания состояния playerItem
            playerItemObserver = playerLayer.player?.currentItem?.observe(\.status, options: [.new])
            {
                [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    switch item.status {
                    case .readyToPlay:
                        self.isLoading = false
                        // Запускаем воспроизведение только если view видим
                        if self.isVisible {
                            self.startPlaybackIfReady()
                        }
                        // Принудительно обновляем layout
                        self.setNeedsLayout()
                        self.layoutSubviews()
                    case .failed:
                        self.isLoading = false
                        // Обработка ошибок для внешних URL
                        if let error = item.error {
                            print("❌ Ошибка воспроизведения видео: \(error)")
                            // Для внешних URL можно попробовать перезагрузить
                            if self.isExternalURL {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    self.retryLoading()
                                }
                            }
                        }
                    case .unknown:
                        self.isLoading = true
                        break
                    @unknown default:
                        self.isLoading = false
                        break
                    }
                }
            }

            // Observer для зацикливания
            if let playerItem = playerLayer.player?.currentItem {
                didPlayToEndObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [weak self] _ in
                    guard let self = self, self.isVisible else { return }
                    // Перематываем на начало и перезапускаем
                    self.playerLayer.player?.seek(to: .zero) { [weak self] finished in
                        if finished {
                            self?.playerLayer.player?.play()
                        }
                    }
                }
            }

            // Проверяем текущий статус
            startPlaybackIfReady()
        }
        
        private func startPlaybackIfReady() {
            guard isVisible else { return }
            
            guard let player = playerLayer.player else { return }
            
            // Проверяем статус playerItem
            guard let playerItem = player.currentItem else { return }
            
            if playerItem.status == .readyToPlay {
                // Если видео уже играло и было остановлено, перематываем на начало
                let currentTime = player.currentTime()
                let duration = playerItem.duration
                
                // Проверяем, дошло ли видео до конца или почти до конца
                if hasPlayedBefore && !currentTime.isIndefinite && !duration.isIndefinite {
                    let currentSeconds = CMTimeGetSeconds(currentTime)
                    let durationSeconds = CMTimeGetSeconds(duration)
                    
                    // Если видео доиграло до конца или почти до конца (в пределах 0.5 секунды)
                    if currentSeconds >= durationSeconds - 0.5 || currentSeconds >= durationSeconds {
                        player.seek(to: .zero) { [weak self] finished in
                            guard let self = self else { return }
                            if finished {
                                self.playerLayer.player?.play()
                            }
                        }
                        return
                    }
                }
                
                // Если видео не играло или находится не в конце, просто запускаем
                if player.timeControlStatus != .playing {
                    player.play()
                    hasPlayedBefore = true
                }
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
            let wasVisible = isVisible
            isVisible = visible
            
            guard let player = playerLayer.player else { return }
            
            if visible {
                // Когда view становится видимым, запускаем воспроизведение
                if !wasVisible {
                    // Если view стал видимым после того, как был скрыт, перезапускаем
                    startPlaybackIfReady()
                } else {
                    // Если view уже был видимым, просто продолжаем воспроизведение
                    if player.timeControlStatus != .playing {
                        player.play()
                    }
                }
            } else {
                // Когда view скрывается, останавливаем воспроизведение
                player.pause()
            }
        }
    }

    struct VideoBackgroundView: UIViewRepresentable {
        let player: AVPlayer
        let isMuted: Bool
        var isVisible: Bool = true

        init(player: AVPlayer, isMuted: Bool = true, isVisible: Bool = true) {
            self.player = player
            self.isMuted = isMuted
            self.isVisible = isVisible
        }

        func makeUIView(context: Context) -> VideoPlayerView {
            let view = VideoPlayerView(player: player, isMuted: isMuted)
            context.coordinator.view = view
            context.coordinator.isVisible = isVisible
            view.setVisible(isVisible)
            return view
        }

        func updateUIView(_ uiView: VideoPlayerView, context: Context) {
            context.coordinator.view = uiView
            
            // Обновляем видимость
            if context.coordinator.isVisible != isVisible {
                context.coordinator.isVisible = isVisible
                uiView.setVisible(isVisible)
            }
            
            // Обновляем плеер если нужно
            if uiView.playerLayer.player !== player {
                uiView.playerLayer.player = player
                // Переустанавливаем наблюдатели при смене плеера
                uiView.setupPlayerObservers()
            }

            // Принудительно обновляем layout
            DispatchQueue.main.async {
                uiView.setNeedsLayout()
                uiView.layoutSubviews()
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        class Coordinator {
            weak var view: VideoPlayerView?
            var isVisible: Bool = true
        }
        
        static func dismantleUIView(_ uiView: VideoPlayerView, coordinator: Coordinator) {
            coordinator.isVisible = false
            uiView.setVisible(false)
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
