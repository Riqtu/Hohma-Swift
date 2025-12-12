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
#if canImport(UIKit)
import UIKit
#endif

struct VideoMessagePlayerView: View {
    @ObserveInjection var inject
    let messageId: String
    let url: URL
    let isCurrentUser: Bool
    @State private var player: AVPlayer?
    @State private var isExpanded = false // Развернуто ли видео на всю ширину
    
    // Размеры для круга и полного экрана
    private let circleSize: CGFloat = 200
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        Button(action: {
            // При нажатии переключаем между маленьким и большим размером
            isExpanded.toggle()
            updatePlayerState()
        }) {
            ZStack {
                if let player = player {
                    // Видео - круг, который увеличивается при нажатии
                    VideoPlayerLayer(player: player, isExpanded: isExpanded)
                        .frame(
                            width: isExpanded ? nil : circleSize,
                            height: isExpanded ? nil : circleSize
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: isExpanded ? .infinity : nil)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isCurrentUser ? Color.white.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                } else {
                    // Placeholder пока загружается - всегда круг
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(
                        width: isExpanded ? nil : circleSize,
                        height: isExpanded ? nil : circleSize
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: isExpanded ? .infinity : nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        }
        .buttonStyle(.plain)
        .frame(height: isExpanded ? nil : circleSize) // Фиксированная высота только для круга
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .onAppear {
            // Создаем плеер асинхронно, чтобы не блокировать скролл
            Task { @MainActor in
                setupPlayer()
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: isExpanded) { _, _ in
            updatePlayerState()
        }
        .enableInjection()
    }
    
    private func setupPlayer() {
        // Создаем новый плеер каждый раз
        let newPlayer = AVPlayer(url: url)
        self.player = newPlayer
        
        // Автоматически запускаем воспроизведение в маленьком виде без звука
        newPlayer.isMuted = !isExpanded
        newPlayer.play()
        
        // Наблюдаем за завершением воспроизведения - перезапускаем
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
    }
    
    private func updatePlayerState() {
        guard let player = player else { return }
        
        if isExpanded {
            // При разворачивании включаем звук
            player.isMuted = false
            if player.rate == 0 {
                player.play()
            }
        } else {
            // При сворачивании выключаем звук
            player.isMuted = true
            // Воспроизведение продолжается, но без звука
            if player.rate == 0 {
                player.play()
            }
        }
    }
    
    private func cleanupPlayer() {
        guard let player = player else { return }
        
        // Удаляем observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        
        // Паузим и удаляем плеер
        player.pause()
        self.player = nil
    }
}

// MARK: - Video Player Layer без элементов управления
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    let isExpanded: Bool
    
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
                        AppLogger.shared.error("Failed to load video track properties: \(error)", category: .ui)
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
        // Обновляем frame слоя на всю доступную область
        if let layer = playerLayer {
            layer.frame = bounds
        }
    }
}

