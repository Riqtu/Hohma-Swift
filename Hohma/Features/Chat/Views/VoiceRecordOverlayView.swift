//
//  VoiceRecordOverlayView.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import SwiftUI
import Inject

struct VoiceRecordOverlayView: View {
    @ObserveInjection var inject
    let duration: TimeInterval
    let audioLevel: Float
    let isCanceling: Bool
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Размытый полупрозрачный фон на весь экран
            Rectangle()
                .fill(Material.thinMaterial)
                .overlay(
                    Color.black.opacity(0.2)
                )
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Индикатор отмены сверху
                if isCanceling {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Отменить")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Кружок с визуализацией
                ZStack {
                    // Внешний круг с пульсацией
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 120 + CGFloat(audioLevel * 40), height: 120 + CGFloat(audioLevel * 40))
                        .scaleEffect(isCanceling ? 0.8 : 1.0)
                    
                    // Средний круг
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 100 + CGFloat(audioLevel * 30), height: 100 + CGFloat(audioLevel * 30))
                    
                    // Внутренний круг
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80 + CGFloat(audioLevel * 20), height: 80 + CGFloat(audioLevel * 20))
                    
                    // Микрофон внутри
                    Image(systemName: "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
                .animation(.easeInOut(duration: 0.2), value: isCanceling)
                
                // Длительность записи
                Text(formatDuration(duration))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Подсказка
                Text(isCanceling ? "Отпустите для отмены" : "Отпустите для отправки")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
            .padding()
        }
        .enableInjection()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

