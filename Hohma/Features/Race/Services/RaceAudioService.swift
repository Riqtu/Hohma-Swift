//
//  RaceAudioService.swift
//  Hohma
//
//  Created by AI Assistant
//

import AVFoundation
import Foundation

@MainActor
class RaceAudioService: NSObject, ObservableObject {
    static let shared = RaceAudioService()
    
    private var backgroundPlayer: AVAudioPlayer?
    private var horseSoundPlayer: AVAudioPlayer?
    private var currentTheme: RaceTheme?
    private var currentVolume: Double = 0.5
    
    override init() {
        super.init()
        setupAudioSession()
        // Загружаем сохраненную громкость
        loadVolume()
    }
    
    private func loadVolume() {
        let savedVolume = UserDefaults.standard.double(forKey: "race_sound_volume")
        if savedVolume > 0 {
            currentVolume = savedVolume
        } else {
            currentVolume = 0.5 // Значение по умолчанию
        }
    }
    
    func updateVolume(_ volume: Double) {
        currentVolume = max(0.0, min(1.0, volume)) // Ограничиваем от 0 до 1
        // Обновляем громкость для фоновой музыки (50% от общей громкости)
        backgroundPlayer?.volume = Float(currentVolume * 0.5)
        // Обновляем громкость для звука лошади (70% от общей громкости)
        horseSoundPlayer?.volume = Float(currentVolume * 0.7)
        print("🔊 RaceAudioService: Volume updated to \(currentVolume)")
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("❌ RaceAudioService: Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Background Music
    
    func playBackgroundMusic(for theme: RaceTheme) {
        // Если уже играет музыка для этой темы, не перезапускаем
        if currentTheme == theme && backgroundPlayer != nil && backgroundPlayer?.isPlaying == true {
            return
        }
        
        // Останавливаем предыдущую музыку
        stopBackgroundMusic()
        
        currentTheme = theme
        
        // Получаем имя файла и расширение для темы
        let (fileName, fileExtension) = theme.backgroundMusicFileName
        
        // Пробуем найти файл в подпапке sound/race
        var url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "sound/race")
        
        // Если не найдено, пробуем без подпапки (на случай, если файлы скопированы в корень)
        if url == nil {
            url = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        }
        
        guard let fileUrl = url else {
            print("❌ RaceAudioService: Background music file not found for theme: \(theme.rawValue) (file: \(fileName).\(fileExtension))")
            return
        }
        
        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            backgroundPlayer?.delegate = self
            backgroundPlayer?.numberOfLoops = -1 // Бесконечный повтор
            backgroundPlayer?.volume = Float(currentVolume * 0.5) // 50% от общей громкости для фоновой музыки
            backgroundPlayer?.prepareToPlay()
            backgroundPlayer?.play()
            print("✅ RaceAudioService: Playing background music for theme: \(theme.rawValue) from: \(fileUrl.lastPathComponent)")
        } catch {
            print("❌ RaceAudioService: Failed to play background music: \(error)")
            backgroundPlayer = nil
        }
    }
    
    func stopBackgroundMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
        currentTheme = nil
        print("🛑 RaceAudioService: Background music stopped")
    }
    
    func pauseBackgroundMusic() {
        backgroundPlayer?.pause()
        print("⏸️ RaceAudioService: Background music paused")
    }
    
    func resumeBackgroundMusic() {
        backgroundPlayer?.play()
        print("▶️ RaceAudioService: Background music resumed")
    }
    
    // MARK: - Horse Sound
    
    func playHorseSound() {
        // Если звук уже играет, не перезапускаем
        if horseSoundPlayer != nil && horseSoundPlayer?.isPlaying == true {
            return
        }
        
        // Пробуем найти файл в подпапке sound/race
        var url = Bundle.main.url(forResource: "horse", withExtension: "wav", subdirectory: "sound/race")
        
        // Если не найдено, пробуем без подпапки
        if url == nil {
            url = Bundle.main.url(forResource: "horse", withExtension: "wav")
        }
        
        guard let fileUrl = url else {
            print("❌ RaceAudioService: Horse sound file not found")
            return
        }
        
        do {
            horseSoundPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            horseSoundPlayer?.delegate = self
            horseSoundPlayer?.numberOfLoops = 0 // Воспроизводим один раз
            horseSoundPlayer?.volume = Float(currentVolume * 0.7) // 70% от общей громкости для звука лошади
            horseSoundPlayer?.prepareToPlay()
            horseSoundPlayer?.play()
            print("🐴 RaceAudioService: Playing horse sound from: \(fileUrl.lastPathComponent)")
        } catch {
            print("❌ RaceAudioService: Failed to play horse sound: \(error)")
            horseSoundPlayer = nil
        }
    }
    
    func stopHorseSound() {
        horseSoundPlayer?.stop()
        horseSoundPlayer = nil
        print("🛑 RaceAudioService: Horse sound stopped")
    }
    
    // MARK: - Cleanup
    
    func stopAll() {
        stopBackgroundMusic()
        stopHorseSound()
    }
}

// MARK: - AVAudioPlayerDelegate
extension RaceAudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == backgroundPlayer {
            // Фоновая музыка должна повторяться бесконечно, но на всякий случай перезапускаем
            if let theme = currentTheme {
                playBackgroundMusic(for: theme)
            }
        } else if player == horseSoundPlayer {
            // Звук лошади закончился - это нормально
            horseSoundPlayer = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ RaceAudioService: Decode error: \(error?.localizedDescription ?? "unknown")")
        if player == backgroundPlayer {
            backgroundPlayer = nil
            currentTheme = nil
        } else if player == horseSoundPlayer {
            horseSoundPlayer = nil
        }
    }
}

