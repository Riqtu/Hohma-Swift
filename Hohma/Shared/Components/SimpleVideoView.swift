import AVFoundation
import SwiftUI

#if os(iOS)
    import UIKit

    class SimpleVideoPlayerView: UIView {
        private var playerLayer: AVPlayerLayer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = UIColor.red  // Красный фон для отладки
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setPlayer(_ player: AVPlayer) {
            print("🎬 SimpleVideoPlayerView: Устанавливаем плеер")

            // Удаляем старый layer если есть
            playerLayer?.removeFromSuperlayer()

            // Создаем новый layer
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.backgroundColor = UIColor.blue.cgColor  // Синий фон для отладки
            layer.opacity = 1.0

            self.playerLayer = layer
            self.layer.addSublayer(layer)

            // Устанавливаем frame
            DispatchQueue.main.async {
                layer.frame = self.bounds
                print("🎬 SimpleVideoPlayerView: Frame установлен: \(self.bounds)")
            }

            // Запускаем воспроизведение
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.currentItem?.status == .readyToPlay {
                    print("🎬 SimpleVideoPlayerView: Запускаем воспроизведение")
                    player.play()
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            print("🎬 SimpleVideoPlayerView: layoutSubviews, bounds: \(bounds)")
            playerLayer?.frame = bounds
        }
    }

    struct SimpleVideoView: UIViewRepresentable {
        let player: AVPlayer

        func makeUIView(context: Context) -> SimpleVideoPlayerView {
            let view = SimpleVideoPlayerView()
            view.setPlayer(player)
            return view
        }

        func updateUIView(_ uiView: SimpleVideoPlayerView, context: Context) {
            uiView.setPlayer(player)
        }
    }

#elseif os(macOS)
    import AppKit

    class SimpleVideoPlayerView: NSView {
        private var playerLayer: AVPlayerLayer?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.backgroundColor = NSColor.red.cgColor  // Красный фон для отладки
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setPlayer(_ player: AVPlayer) {
            print("🎬 SimpleVideoPlayerView (macOS): Устанавливаем плеер")

            // Удаляем старый layer если есть
            playerLayer?.removeFromSuperlayer()

            // Создаем новый layer
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.backgroundColor = NSColor.blue.cgColor  // Синий фон для отладки
            layer.opacity = 1.0

            self.playerLayer = layer
            self.layer?.addSublayer(layer)

            // Устанавливаем frame
            DispatchQueue.main.async {
                layer.frame = self.bounds
                print("🎬 SimpleVideoPlayerView (macOS): Frame установлен: \(self.bounds)")
            }

            // Запускаем воспроизведение
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.currentItem?.status == .readyToPlay {
                    print("🎬 SimpleVideoPlayerView (macOS): Запускаем воспроизведение")
                    player.play()
                }
            }
        }

        override func layout() {
            super.layout()
            print("🎬 SimpleVideoPlayerView (macOS): layout, bounds: \(bounds)")
            playerLayer?.frame = bounds
        }
    }

    struct SimpleVideoView: NSViewRepresentable {
        let player: AVPlayer

        func makeNSView(context: Context) -> SimpleVideoPlayerView {
            let view = SimpleVideoPlayerView()
            view.setPlayer(player)
            return view
        }

        func updateNSView(_ nsView: SimpleVideoPlayerView, context: Context) {
            nsView.setPlayer(player)
        }
    }
#endif
