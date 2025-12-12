//
//  AudioPlayerService.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import Foundation

class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var updateTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            AppLogger.shared.error("Failed to setup audio session: \(error)", category: .general)
        }
    }
    
    func play(url: URL) {
        // Если уже играет тот же файл, пауза/воспроизведение
        if currentURL == url && audioPlayer != nil {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        
        // Останавливаем текущее воспроизведение
        stop()
        
        currentURL = url
        
        do {
            // Сначала пытаемся загрузить из URL
            let audioData = try Data(contentsOf: url)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            
            audioPlayer?.play()
            isPlaying = true
            
            // Запускаем таймер для обновления времени
            startUpdateTimer()
            
            AppLogger.shared.info("Playing audio from URL", category: .general)
        } catch {
            AppLogger.shared.error("Failed to play audio: \(error)", category: .general)
            currentURL = nil
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopUpdateTimer()
    }
    
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startUpdateTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentURL = nil
        stopUpdateTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(time, 0), duration)
        currentTime = player.currentTime
    }
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            if !player.isPlaying {
                self.isPlaying = false
                self.stopUpdateTimer()
            }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopUpdateTimer()
        AppLogger.shared.info("Audio finished playing", category: .general)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        AppLogger.shared.error("Decode error: \(error?.localizedDescription ?? "unknown")", category: .general)
        stop()
    }
}

