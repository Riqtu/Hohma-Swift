import AVFoundation
import Inject
import SwiftUI

/// Специализированный SwiftUI компонент для отображения потокового видео
struct StreamVideoView: View {
    @ObserveInjection var inject
    let url: URL
    @StateObject private var streamPlayer: StreamPlayer

    init(url: URL) {
        self.url = url
        self._streamPlayer = StateObject(
            wrappedValue: StreamVideoService.shared.getStreamPlayer(for: url))
    }

    var body: some View {
        ZStack {
            // Показываем полупрозрачный градиентный фон, пока видео не готово
            if !streamPlayer.isReady {
                AnimatedGradientBackground()
                    .opacity(0.5)  // Полупрозрачность
            }

            // Показываем видео только когда оно готово
            if streamPlayer.isReady {
                StreamVideoPlayerView(player: streamPlayer)
            } else if streamPlayer.isLoading {
                // Индикатор загрузки поверх градиента
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Загрузка видео...")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            } else if streamPlayer.hasError {
                // Показываем ошибку поверх градиента
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Ошибка загрузки видео")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // View появился - принудительно запускаем загрузку
            if streamPlayer.isReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    streamPlayer.play()
                }
            }
        }
        .onDisappear {
            // View исчез
        }
        .enableInjection()
    }
}

// MARK: - StreamVideoPlayerView

#if os(iOS)
    struct StreamVideoPlayerView: UIViewRepresentable {
        let player: StreamPlayer

        func makeUIView(context: Context) -> StreamVideoUIView {
            let view = StreamVideoUIView()
            view.setupPlayer(player)
            return view
        }

        func updateUIView(_ uiView: StreamVideoUIView, context: Context) {
            // Обновления не требуются
        }
    }

    class StreamVideoUIView: UIView {
        private var playerLayer: AVPlayerLayer?

        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        func setupPlayer(_ player: StreamPlayer) {
            guard let avPlayer = player.avPlayer else { return }

            playerLayer = layer as? AVPlayerLayer
            playerLayer?.player = avPlayer
            playerLayer?.videoGravity = .resizeAspectFill
            playerLayer?.backgroundColor = UIColor.clear.cgColor

            // Принудительно запускаем видео после настройки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if player.isReady {
                    player.play()
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }

#elseif os(macOS)
    struct StreamVideoPlayerView: NSViewRepresentable {
        let player: StreamPlayer

        func makeNSView(context: Context) -> StreamVideoNSView {
            let view = StreamVideoNSView()
            view.setupPlayer(player)
            return view
        }

        func updateNSView(_ nsView: StreamVideoNSView, context: Context) {
            // Обновления не требуются
        }
    }

    class StreamVideoNSView: NSView {
        private var playerLayer: AVPlayerLayer?

        override func makeBackingLayer() -> CALayer {
            let layer = AVPlayerLayer()
            playerLayer = layer
            return layer
        }

        func setupPlayer(_ player: StreamPlayer) {
            guard let avPlayer = player.avPlayer else { return }

            playerLayer?.player = avPlayer
            playerLayer?.videoGravity = .resizeAspectFill
            playerLayer?.backgroundColor = NSColor.clear.cgColor

        }

        override func layout() {
            super.layout()
            playerLayer?.frame = bounds
        }
    }
#endif
