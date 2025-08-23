import AVFoundation
import SwiftUI

#if os(iOS)
    import UIKit

    class VideoPlayerView: UIView {
        let playerLayer: AVPlayerLayer
        private var timeObserver: Any?
        private var playerItemObserver: NSKeyValueObservation?
        private var isVisible: Bool = true

        init(player: AVPlayer) {
            self.playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)

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
                    if item.status == .readyToPlay {
                        self?.playerLayer.player?.play()

                        // Принудительно обновляем layout
                        self?.setNeedsLayout()
                        self?.layoutSubviews()
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

        func makeUIView(context: Context) -> VideoPlayerView {
            let view = VideoPlayerView(player: player)
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

        init(player: AVPlayer) {
            self.playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)

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

        func makeNSView(context: Context) -> VideoPlayerView {
            let view = VideoPlayerView(player: player)
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
