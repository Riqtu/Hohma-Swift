//
//  WheelListView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//
import SwiftUI
import AVFoundation

struct WheelCardView: View {
    let cardData: WheelWithRelations
    var player: AVPlayer? {
        guard let urlString = cardData.theme?.backgroundVideoURL,
              let url = URL(string: urlString)
        else { return nil }
        return VideoPlayerManager.shared.player(url: url)
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack(){
                if let player {
                    VideoBackgroundView(player: player)
                        .frame(width: 380, height: 200)
                } else {
                    Color.gray.frame(width: 380, height: 200)
                        .overlay(Text("Нет видео").foregroundColor(.white))
                }
                if cardData.sectors.contains(where: { $0.winner }) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                } else {
                    Text("Колесо фортуны")
                        .font(.title)
                        .fontWeight(.semibold)
                }
            }
            Text(cardData.name)
                .font(.title)
                .fontWeight(.semibold)
                .padding(.bottom)
        }
        .background(Color("AccentColor").opacity(0.7))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        .frame(maxWidth: 380)
        .padding(.horizontal)
    }
    
    
}

// MARK: - Пример тестовых данных для WheelWithRelations

extension WheelWithRelations {
    static var test: WheelWithRelations {
        WheelWithRelations(
            
                id: "6847097426a12d6fd5c0292b",
                name: "Хохма Колесо 09 июня 2025",
                status: .created,
                createdAt: ISO8601DateFormatter().date(from: "2025-06-09T16:19:00.078Z") ?? Date(),
                updatedAt: ISO8601DateFormatter().date(from: "2025-06-09T16:19:00.078Z") ?? Date(),
                themeId: "67fa906964f9f864dc8e0590",
                userId: "6804fc3fd253e514c3fb6ae0",
            
            sectors: [
                .mock
            ],
            bets: [],
            theme: .mock,
            user: .mock
        )
    }
}

#Preview {
    WheelCardView(cardData: .test)
}

