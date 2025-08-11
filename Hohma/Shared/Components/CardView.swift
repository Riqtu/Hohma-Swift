import AVFoundation
//
//  CardView.swift
//  Hohma
//
//  Created by Artem Vydro on 03.08.2025.
//
import SwiftUI

struct CardView: View {
    let title: String
    let description: String
    let imageName: String?  // имя в Assets или URL
    let videoName: String?  // имя видео в Assets
    let player: AVPlayer?  // <-- сюда передавай готовый

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Показываем либо видео, либо картинку, либо ничего
            Group {
                if let player {
                    VideoBackgroundView(player: player)
                } else if let imageName, !imageName.isEmpty {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(title)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.horizontal)
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer(minLength: 0)
        }
        .cardStyle()
        .frame(maxWidth: 380)
        .padding(.horizontal)
    }
}

#Preview {
    CardView(
        title: "Заголовок карточки",
        description:
            "Тут может быть краткое описание, детали, и даже несколько строк текста. Всё как надо.",
        imageName: "testImage",
        videoName: "background",
        player: VideoPlayerManager.shared.player(resourceName: "background")

    )
}
