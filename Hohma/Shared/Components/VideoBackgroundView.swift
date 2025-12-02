import AVFoundation
import SwiftUI
import UIKit

/// Видео фон компонент с поддержкой управления звуком и бесконечного зацикливания
///
/// Пример использования:
/// ```swift
/// // Без звука (не прерывает Spotify/Apple Music)
/// VideoBackgroundView(player: player, isMuted: true)
///
/// // Со звуком (может прерывать другие приложения)
/// VideoBackgroundView(player: player, isMuted: false)
/// ```
class VideoPlayerView: UIView {
    let playerLayer: AVPlayerLayer
    private var statusObserver: NSKeyValueObservation?
    private var isVisible: Bool = true

    init(player: AVPlayer, isMuted: Bool = true) {
        self.playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)

        // Настраиваем layer
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)

        // Настраиваем аудиосессию
        setupAudioSession(isMuted: isMuted)

        // Настраиваем observer для готовности
        setupObserver(player: player)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        statusObserver?.invalidate()
    }

    private func setupAudioSession(isMuted: Bool) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if isMuted {
                try audioSession.setCategory(
                    .playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            } else {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            }
            try audioSession.setActive(true)
        } catch {
            print("❌ Ошибка настройки аудиосессии: \(error)")
        }
    }

    func setupObserver(player: AVPlayer) {
        // Очищаем предыдущий observer
        statusObserver?.invalidate()

        statusObserver = player.currentItem?.observe(\.status, options: [.new]) {
            [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.status == .readyToPlay && self.isVisible {
                    if player.timeControlStatus != .playing {
                        player.play()
                    }
                }
            }
        }

        // Если уже готов, запускаем сразу
        if player.currentItem?.status == .readyToPlay && isVisible {
            if player.timeControlStatus != .playing {
                player.play()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
        guard let player = playerLayer.player else { return }

        if visible {
            // Запускаем видео если оно готово
            if player.currentItem?.status == .readyToPlay {
                if player.timeControlStatus != .playing {
                    player.play()
                }
            }
        } else {
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
            // Переустанавливаем observer для нового плеера
            uiView.setupObserver(player: player)
        }

        // Если view видим и видео готово, но не играет - запускаем
        if isVisible {
            if let playerItem = player.currentItem, playerItem.status == .readyToPlay {
                if player.timeControlStatus != .playing {
                    player.play()
                }
            }
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
