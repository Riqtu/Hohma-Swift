//
//  VoiceMessagePlayerView.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import Inject
import SwiftUI

struct VoiceMessagePlayerView: View {
    @ObserveInjection var inject
    let url: URL
    let isCurrentUser: Bool
    @StateObject private var playerService = AudioPlayerService()
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var duration: TimeInterval = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Кнопка воспроизведения
            Button(action: {
                playerService.play(url: url)
            }) {
                Image(systemName: playerService.isPlaying && playerService.currentURL == url
                      ? "pause.circle.fill"
                      : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(isCurrentUser ? .white : Color("AccentColor"))
            }
            
            // Прогресс-бар и время
            VStack(alignment: .leading, spacing: 4) {
                // Прогресс-бар
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Фон прогресс-бара
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                        
                        // Прогресс воспроизведения
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(
                                width: geometry.size.width * CGFloat((isDragging ? dragValue : playerService.currentTime) / max(playerService.duration > 0 ? playerService.duration : duration, 0.1)),
                                height: 4
                            )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let totalDuration = playerService.duration > 0 ? playerService.duration : duration
                                let progress = min(max(value.location.x / geometry.size.width, 0), 1)
                                dragValue = progress * totalDuration
                            }
                            .onEnded { _ in
                                playerService.seek(to: dragValue)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 4)
                
                // Время
                HStack {
                    Text(formatTime(isDragging ? dragValue : playerService.currentTime))
                        .font(.caption2)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                    
                    Text("/")
                        .font(.caption2)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                    
                    Text(formatTime(playerService.duration > 0 ? playerService.duration : duration))
                        .font(.caption2)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isCurrentUser
                ? Color("AccentColor").opacity(0.9)
                : Color(.systemGray6)
        )
        .cornerRadius(16)
        .onAppear {
            // Загружаем длительность при появлении
            loadDuration()
        }
        .enableInjection()
    }
    
    private func loadDuration() {
        // Асинхронно загружаем длительность аудио
        Task {
            do {
                let audioData = try Data(contentsOf: url)
                if let player = try? AVAudioPlayer(data: audioData) {
                    await MainActor.run {
                        let loadedDuration = player.duration
                        duration = loadedDuration
                        if playerService.duration == 0 {
                            playerService.duration = loadedDuration
                        }
                    }
                }
            } catch {
                print("❌ VoiceMessagePlayerView: Failed to load duration: \(error)")
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

