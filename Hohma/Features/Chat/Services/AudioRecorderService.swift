//
//  AudioRecorderService.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import Foundation

class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Запрашиваем разрешение на микрофон (используем новый API для iOS 17+)
            if #available(iOS 17.0, *) {
                switch AVAudioApplication.shared.recordPermission {
                case .undetermined:
                    AVAudioApplication.requestRecordPermission { granted in
                        if granted {
                            AppLogger.shared.info("Microphone permission granted", category: .general)
                        } else {
                            AppLogger.shared.error("Microphone permission denied", category: .general)
                        }
                    }
                    return
                case .denied:
                    AppLogger.shared.error("Microphone permission denied", category: .general)
                    return
                case .granted:
                    break
                @unknown default:
                    break
                }
            } else {
                // Fallback для iOS < 17
                if audioSession.recordPermission == .undetermined {
                    audioSession.requestRecordPermission { granted in
                        if granted {
                            AppLogger.shared.info("Microphone permission granted", category: .general)
                        } else {
                            AppLogger.shared.error("Microphone permission denied", category: .general)
                        }
                    }
                    return
                }
                
                guard audioSession.recordPermission == .granted else {
                    AppLogger.shared.error("Microphone permission not granted", category: .general)
                    return
                }
            }
            
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            AppLogger.shared.error("Failed to setup audio session: \(error)", category: .general)
        }
    }
    
    func startRecording() -> URL? {
        guard !isRecording else { return nil }
        
        // Проверяем разрешение на микрофон (используем новый API для iOS 17+)
        let audioSession = AVAudioSession.sharedInstance()
        
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            _ = self?.startRecording()
                        }
                    } else {
                        AppLogger.shared.error("Microphone permission denied", category: .general)
                    }
                }
                return nil
            case .denied:
                AppLogger.shared.error("Microphone permission denied", category: .general)
                return nil
            case .granted:
                break
            @unknown default:
                return nil
            }
        } else {
            // Fallback для iOS < 17
            if audioSession.recordPermission == .undetermined {
                audioSession.requestRecordPermission { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            _ = self?.startRecording()
                        }
                    } else {
                        AppLogger.shared.error("Microphone permission denied", category: .general)
                    }
                }
                return nil
            }
            
            guard audioSession.recordPermission == .granted else {
                AppLogger.shared.error("Microphone permission not granted", category: .general)
                return nil
            }
        }
        
        // Настраиваем аудиосессию перед записью
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            AppLogger.shared.error("Failed to setup audio session: \(error)", category: .general)
            return nil
        }
        
        // Создаем временный файл для записи в Caches (не в Documents)
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let audioFilename = cachesPath.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        recordingURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.record() == true else {
                AppLogger.shared.error("Failed to start recording", category: .general)
                return nil
            }
            
            isRecording = true
            recordingDuration = 0
            
            // Таймер для отслеживания длительности
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingDuration += 0.1
            }
            
            // Таймер для отслеживания уровня звука
            audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let level = recorder.averagePower(forChannel: 0)
                // Нормализуем уровень от -160 до 0 в диапазон 0-1
                let normalizedLevel = pow(10, level / 20)
                self.audioLevel = min(max(normalizedLevel * 2, 0.1), 1.0)
            }
            
            AppLogger.shared.info("Recording started", category: .general)
            return audioFilename
        } catch {
            AppLogger.shared.error("Failed to create audio recorder: \(error)", category: .general)
            return nil
        }
    }
    
    func stopRecording() -> Data? {
        guard isRecording, let recorder = audioRecorder, let url = recordingURL else {
            return nil
        }
        
        recorder.stop()
        isRecording = false
        recordingDuration = 0
        audioLevel = 0.0
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Читаем записанный файл
        do {
            let audioData = try Data(contentsOf: url)
            
            // Удаляем временный файл
            try? FileManager.default.removeItem(at: url)
            
            AppLogger.shared.info("Recording stopped, duration: \(audioData.count) bytes", category: .general)
            return audioData
        } catch {
            AppLogger.shared.error("Failed to read recording: \(error)", category: .general)
            return nil
        }
    }
    
    func cancelRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        recordingDuration = 0
        audioLevel = 0.0
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Удаляем временный файл
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        
        AppLogger.shared.error("Recording cancelled", category: .general)
    }
    
    deinit {
        // Освобождаем таймеры при уничтожении объекта
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()
        
        // Останавливаем запись, если она активна
        if isRecording {
            audioRecorder?.stop()
        }
        
        // Удаляем временный файл
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            AppLogger.shared.warning("Recording finished with error", category: .general)
            isRecording = false
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        AppLogger.shared.error("Encoding error: \(error?.localizedDescription ?? "unknown")", category: .general)
        isRecording = false
    }
}

