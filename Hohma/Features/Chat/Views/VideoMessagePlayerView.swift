//
//  VideoMessagePlayerView.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import AVKit
import Inject
import SwiftUI

struct VideoMessagePlayerView: View {
    @ObserveInjection var inject
    let url: URL
    let isCurrentUser: Bool
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var timeObserver: Any?
    
    var body: some View {
        Button(action: {
            guard let player = player else { return }
            if isPlaying {
                player.pause()
            } else {
                player.play()
            }
        }) {
            ZStack {
                if let player = player {
                    // Видео как круг (кружок) - вписывается в круг
                    VideoPlayerLayer(player: player)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isCurrentUser ? Color.white.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .overlay(
                            // Кнопка воспроизведения
                            Group {
                                if !isPlaying {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .shadow(radius: 10)
                                }
                            }
                        )
                } else {
                    // Placeholder пока загружается
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 200)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .enableInjection()
    }
    
    private func setupPlayer() {
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        // Наблюдаем за завершением воспроизведения
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            isPlaying = false
            newPlayer?.seek(to: .zero)
        }
        
        // Наблюдаем за статусом воспроизведения
        let observer = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak newPlayer] _ in
            if newPlayer?.rate ?? 0 > 0 {
                isPlaying = true
            } else {
                isPlaying = false
            }
        }
        self.timeObserver = observer
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        timeObserver = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Video Player Layer без элементов управления
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> VideoPlayerUIView {
        let view = VideoPlayerUIView()
        view.setPlayer(player)
        return view
    }
    
    func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
        uiView.setPlayer(player)
    }
}

class VideoPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    func setPlayer(_ player: AVPlayer) {
        if let layer = layer as? AVPlayerLayer {
            layer.player = player
            // Заполняем круг без пустых краев (обрезаем если нужно)
            layer.videoGravity = .resizeAspectFill
            
            // Получаем ориентацию видео из asset (используем новый API)
            if let asset = player.currentItem?.asset {
                Task {
                    do {
                        let tracks = try await asset.loadTracks(withMediaType: .video)
                        if let videoTrack = tracks.first {
                            let size = try await videoTrack.load(.naturalSize)
                            
                            // Применяем трансформацию на главном потоке
                            await MainActor.run {
                                // Проверяем размеры для определения ориентации
                                let isPortrait = size.height > size.width
                                
                                var combinedTransform = CGAffineTransform.identity
                                
                                // Если видео вертикальное (портретное), поворачиваем на 90 градусов
                                if isPortrait {
                                    // Поворачиваем на 90 градусов по часовой стрелке
                                    combinedTransform = combinedTransform.rotated(by: .pi / 2)
                                }
                                
                                // Всегда зеркалим по горизонтали (отзеркаливаем)
                                combinedTransform = combinedTransform.scaledBy(x: -1, y: 1)
                                
                                layer.setAffineTransform(combinedTransform)
                            }
                        }
                    } catch {
                        print("❌ VideoMessagePlayerView: Failed to load video track properties: \(error)")
                        // Fallback: просто зеркалим если не удалось загрузить свойства
                        await MainActor.run {
                            layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                        }
                    }
                }
            } else {
                // Fallback: просто зеркалим если нет asset
                layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
            }
            
            playerLayer = layer
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Убеждаемся, что frame правильный для квадратного круга
        if let layer = playerLayer {
            let size = min(bounds.width, bounds.height)
            let x = (bounds.width - size) / 2
            let y = (bounds.height - size) / 2
            layer.frame = CGRect(x: x, y: y, width: size, height: size)
        }
    }
}

