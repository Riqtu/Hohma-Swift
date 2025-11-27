//
//  VideoPlayerCacheService.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VideoPlayerCacheService {
    static let shared = VideoPlayerCacheService()
    
    private struct PlayerState {
        var currentTime: CMTime
        var isMuted: Bool
        var isPlaying: Bool
    }
    
    struct PlayerResult {
        let player: AVPlayer
        let wasRestored: Bool
    }
    
    private var players: [String: AVPlayer] = [:]
    private var playerStates: [String: PlayerState] = [:]
    private var playerURLs: [String: URL] = [:]
    private var lastUsedDates: [String: Date] = [:]
    private var thumbnails: [String: UIImage] = [:]
    private let maxCachedPlayers = 6
    
    private init() {
#if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.clearCache()
            }
        }
#endif
    }
    
    func acquirePlayer(for messageId: String, url: URL) -> PlayerResult {
        if let existing = players[messageId], playerURLs[messageId] == url {
            restoreStateIfNeeded(for: messageId, player: existing)
            lastUsedDates[messageId] = Date()
            return PlayerResult(player: existing, wasRestored: true)
        }
        
        let player = AVPlayer(url: url)
        players[messageId] = player
        playerURLs[messageId] = url
        lastUsedDates[messageId] = Date()
        enforceLimitIfNeeded()
        return PlayerResult(player: player, wasRestored: false)
    }
    
    func saveState(for messageId: String, player: AVPlayer) {
        playerStates[messageId] = PlayerState(
            currentTime: player.currentTime(),
            isMuted: player.isMuted,
            isPlaying: player.rate > 0
        )
        lastUsedDates[messageId] = Date()
    }
    
    func pausePlayer(for messageId: String) {
        players[messageId]?.pause()
    }
    
    private func restoreStateIfNeeded(for messageId: String, player: AVPlayer) {
        guard let state = playerStates[messageId] else { return }
        player.seek(to: state.currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        player.isMuted = state.isMuted
        if state.isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }
    
    private func enforceLimitIfNeeded() {
        guard players.count > maxCachedPlayers else { return }
        let sorted = lastUsedDates.sorted { $0.value < $1.value }
        let overflow = players.count - maxCachedPlayers
        for idx in 0..<overflow {
            let messageId = sorted[idx].key
            removePlayer(for: messageId)
        }
    }
    
    private func removePlayer(for messageId: String) {
        players[messageId]?.pause()
        players[messageId] = nil
        playerStates[messageId] = nil
        playerURLs[messageId] = nil
        lastUsedDates[messageId] = nil
    }
    
    func getThumbnail(for messageId: String) -> UIImage? {
        return thumbnails[messageId]
    }
    
    func setThumbnail(for messageId: String, image: UIImage) {
        thumbnails[messageId] = image
    }
    
    func clearCache() {
        for (_, player) in players {
            player.pause()
        }
        players.removeAll()
        playerStates.removeAll()
        playerURLs.removeAll()
        lastUsedDates.removeAll()
        thumbnails.removeAll()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

