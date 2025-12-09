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
                            print("✅ AudioRecorderService: Microphone permission granted")
                        } else {
                            print("❌ AudioRecorderService: Microphone permission denied")
                        }
                    }
                    return
                case .denied:
                    print("❌ AudioRecorderService: Microphone permission denied")
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
                            print("✅ AudioRecorderService: Microphone permission granted")
                        } else {
                            print("❌ AudioRecorderService: Microphone permission denied")
                        }
                    }
                    return
                }
                
                guard audioSession.recordPermission == .granted else {
                    print("❌ AudioRecorderService: Microphone permission not granted")
                    return
                }
            }
            
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("❌ AudioRecorderService: Failed to setup audio session: \(error)")
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
                        print("❌ AudioRecorderService: Microphone permission denied")
                    }
                }
                return nil
            case .denied:
                print("❌ AudioRecorderService: Microphone permission denied")
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
                        print("❌ AudioRecorderService: Microphone permission denied")
                    }
                }
                return nil
            }
            
            guard audioSession.recordPermission == .granted else {
                print("❌ AudioRecorderService: Microphone permission not granted")
                return nil
            }
        }
        
        // Настраиваем аудиосессию перед записью
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("❌ AudioRecorderService: Failed to setup audio session: \(error)")
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
                print("❌ AudioRecorderService: Failed to start recording")
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
            
            print("✅ AudioRecorderService: Recording started")
            return audioFilename
        } catch {
            print("❌ AudioRecorderService: Failed to create audio recorder: \(error)")
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
            
            print("✅ AudioRecorderService: Recording stopped, duration: \(audioData.count) bytes")
            return audioData
        } catch {
            print("❌ AudioRecorderService: Failed to read recording: \(error)")
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
        
        print("❌ AudioRecorderService: Recording cancelled")
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("⚠️ AudioRecorderService: Recording finished with error")
            isRecording = false
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ AudioRecorderService: Encoding error: \(error?.localizedDescription ?? "unknown")")
        isRecording = false
    }
}

