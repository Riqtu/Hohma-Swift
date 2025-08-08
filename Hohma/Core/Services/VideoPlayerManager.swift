//
//  VideoPlayerManager.swift
//  Hohma
//
//  Created by Artem Vydro on 03.08.2025.
//
import AVFoundation

final class VideoPlayerManager {
    static let shared = VideoPlayerManager()
    private var cache: [String: AVPlayer] = [:]

    func player(resourceName: String, resourceExtension: String = "mp4") -> AVPlayer? {
        let key = "\(resourceName).\(resourceExtension)"
        if let cachedPlayer = cache[key] {
            return cachedPlayer
        }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            print("❌ Видео не найдено: \(resourceName).\(resourceExtension)")
            return nil
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        cache[key] = player
        return player
    }
    func player(url: URL) -> AVPlayer {
        let key = url.absoluteString
        if let cachedPlayer = cache[key] {
            return cachedPlayer
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        cache[key] = player
        return player
    }
}
