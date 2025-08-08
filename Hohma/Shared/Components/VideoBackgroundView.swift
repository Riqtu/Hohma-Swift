import AVFoundation
import SwiftUI

#if os(iOS)
    import UIKit

    class VideoPlayerView: UIView {
        let playerLayer: AVPlayerLayer
        private var timeObserver: Any?
        private var playerItemObserver: NSKeyValueObservation?

        init(player: AVPlayer) {
            self.playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            self.playerLayer.videoGravity = .resizeAspectFill
            self.layer.addSublayer(playerLayer)

            // Добавляем observer для отслеживания состояния плеера
            setupPlayerObservers()
        }

        required init?(coder: NSCoder) { fatalError() }

        deinit {
            cleanupObservers()
        }

        private func cleanupObservers() {
            if let timeObserver = timeObserver {
                playerLayer.player?.removeTimeObserver(timeObserver)
            }
            playerItemObserver?.invalidate()
            playerItemObserver = nil
        }

        private func setupPlayerObservers() {
            guard let player = playerLayer.player else { return }

            // Добавляем observer для отслеживания времени воспроизведения
            let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
                [weak self] _ in
                // Проверяем, что плеер все еще воспроизводится
                if player.timeControlStatus == .paused {
                    player.play()
                }
            }

            // Добавляем observer для отслеживания состояния playerItem
            playerItemObserver = player.currentItem?.observe(\.status, options: [.new]) {
                [weak self] item, _ in
                DispatchQueue.main.async {
                    if item.status == .readyToPlay {
                        player.play()
                    }
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = self.bounds
        }
    }

    struct VideoBackgroundView: UIViewRepresentable {
        let player: AVPlayer

        func makeUIView(context: Context) -> UIView {
            let view = VideoPlayerView(player: player)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            // frame обновится автоматически через layoutSubviews
        }
    }

#elseif os(macOS)
    import SwiftUI
    import AVKit

    struct VideoBackgroundView: NSViewRepresentable {
        let player: AVPlayer

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.wantsLayer = true
            view.layer = CALayer()

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = view.bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

            view.layer?.addSublayer(playerLayer)

            DispatchQueue.main.async {
                player.play()
            }

            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            if let playerLayer = nsView.layer?.sublayers?.first as? AVPlayerLayer {
                playerLayer.frame = nsView.bounds
            }
        }
    }
#endif
