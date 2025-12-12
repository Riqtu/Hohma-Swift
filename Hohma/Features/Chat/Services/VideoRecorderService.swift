//
//  VideoRecorderService.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import UIKit

class VideoRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var previewLayer: CALayer?
    @Published var isFrontCamera = true  // Для отслеживания позиции камеры

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var recordingURL: URL?
    private var previewLayerInstance: AVCaptureVideoPreviewLayer?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var recordingSegments: [URL] = []  // Для хранения сегментов записи
    private var segmentStartTime: TimeInterval = 0  // Время начала текущего сегмента
    private var isWaitingForSegmentCompletion = false  // Флаг ожидания завершения сегмента
    private var pendingSegmentStart: (() -> Void)?  // Callback для начала следующего сегмента

    override init() {
        super.init()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        // Используем .high для лучшего качества, но записываем квадратное видео
        session.sessionPreset = .high

        // Настраиваем камеру (начинаем с фронтальной)
        currentCameraPosition = .front
        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        else {
            AppLogger.shared.error("Failed to get video device", category: .general)
            return
        }

        do {
            // Видео вход
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoInput = videoInput
            }

            // Аудио вход
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                AppLogger.shared.error("Failed to get audio device", category: .general)
                return
            }

            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                self.audioInput = audioInput
            }

            // Видео вывод
            let videoOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            // Preview слой
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            // Зеркалим для фронтальной камеры
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                // Отключаем автоматическое зеркалирование перед ручной установкой
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = (currentCameraPosition == .front)
            }
            self.previewLayerInstance = previewLayer
            self.previewLayer = previewLayer
            self.isFrontCamera = (currentCameraPosition == .front)

            self.captureSession = session
        } catch {
            AppLogger.shared.error("Failed to setup capture session: \(error)", category: .general)
        }
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                DispatchQueue.main.async {
                    completion(videoGranted && audioGranted)
                }
            }
        }
    }

    @available(iOS, deprecated: 17.0, message: "Use getVideoRotationAngle() instead")
    private func getVideoOrientation() -> AVCaptureVideoOrientation {
        // Получаем ориентацию интерфейса, если доступна
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let interfaceOrientation = windowScene.interfaceOrientation
            switch interfaceOrientation {
            case .portrait:
                return .portrait
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            default:
                return .portrait
            }
        }

        // Fallback на ориентацию устройства
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait, .faceUp, .faceDown, .unknown:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        @unknown default:
            return .portrait
        }
    }

    private func getVideoRotationAngle() -> CGFloat {
        // Получаем ориентацию интерфейса, если доступна
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let interfaceOrientation = windowScene.interfaceOrientation
            switch interfaceOrientation {
            case .portrait:
                return 90.0
            case .portraitUpsideDown:
                return 270.0
            case .landscapeLeft:
                return 0.0
            case .landscapeRight:
                return 180.0
            default:
                return 90.0
            }
        }

        // Fallback на ориентацию устройства
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait, .faceUp, .faceDown, .unknown:
            return 90.0
        case .portraitUpsideDown:
            return 270.0
        case .landscapeLeft:
            return 0.0
        case .landscapeRight:
            return 180.0
        @unknown default:
            return 90.0
        }
    }

    func startRecording() -> URL? {
        guard !isRecording else {
            AppLogger.shared.warning("Recording already in progress", category: .general)
            return nil
        }
        guard let session = captureSession, let output = videoOutput else { return nil }

        // Проверяем, не идет ли уже запись у output
        if output.isRecording {
            AppLogger.shared.warning("Output is already recording", category: .general)
            return nil
        }

        // Запускаем сессию если не запущена
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        // Устанавливаем ориентацию для записи
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                let rotationAngle = getVideoRotationAngle()
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
            } else {
                let videoOrientation = getVideoOrientation()
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
            }
        }

        // Создаем временный файл для записи в Caches (не в Documents, чтобы не копить пользовательские данные)
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let videoFilename = cachesPath.appendingPathComponent("video_\(UUID().uuidString).mp4")
        recordingURL = videoFilename
        recordingSegments = [videoFilename]  // Инициализируем список сегментов
        segmentStartTime = 0
        isWaitingForSegmentCompletion = false
        pendingSegmentStart = nil

        // Удаляем файл если существует
        try? FileManager.default.removeItem(at: videoFilename)

        // Начинаем запись
        output.startRecording(to: videoFilename, recordingDelegate: self)

        isRecording = true
        recordingDuration = 0

        // Таймер для отслеживания длительности
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.1
        }

        AppLogger.shared.info("Recording started", category: .general)
        return videoFilename
    }

    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard isRecording, let output = videoOutput else {
            completion(nil)
            return
        }

        output.stopRecording()

        recordingTimer?.invalidate()
        recordingTimer = nil

        // Ждем завершения записи в делегате
        // completion будет вызван в fileOutput:didFinishRecordingTo:...
        stopRecordingCompletion = completion
    }

    private var stopRecordingCompletion: ((Data?) -> Void)?

    func cancelRecording() {
        guard isRecording else { return }

        videoOutput?.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Удаляем файл
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        isRecording = false
        recordingDuration = 0
        recordingURL = nil
        recordingSegments.removeAll()
        segmentStartTime = 0
        stopRecordingCompletion = nil

        AppLogger.shared.info("Recording cancelled", category: .general)
    }

    private func mergeVideoSegments(completion: @escaping (Data?) -> Void) {
        // Объединение нескольких видео сегментов в один файл
        Task {
            let composition = AVMutableComposition()

            guard
                let videoTrack = composition.addMutableTrack(
                    withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                let audioTrack = composition.addMutableTrack(
                    withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else {
                completion(nil)
                return
            }

            var currentTime = CMTime.zero
            var firstSegmentTransform: CGAffineTransform?

            for segmentURL in recordingSegments {
                let asset = AVURLAsset(url: segmentURL)

                do {
                    let videoTracks = try await asset.loadTracks(withMediaType: .video)
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)

                    guard let segmentVideoTrack = videoTracks.first,
                        let segmentAudioTrack = audioTracks.first
                    else {
                        continue
                    }

                    let videoTimeRange = try await segmentVideoTrack.load(.timeRange)
                    let audioTimeRange = try await segmentAudioTrack.load(.timeRange)

                    // Сохраняем transform первого сегмента для применения к композиции
                    if firstSegmentTransform == nil {
                        firstSegmentTransform = try await segmentVideoTrack.load(
                            .preferredTransform)
                    }

                    try videoTrack.insertTimeRange(
                        videoTimeRange, of: segmentVideoTrack, at: currentTime)
                    try audioTrack.insertTimeRange(
                        audioTimeRange, of: segmentAudioTrack, at: currentTime)

                    currentTime = CMTimeAdd(currentTime, videoTimeRange.duration)
                } catch {
                    AppLogger.shared.error("Failed to merge segment: \(error)", category: .general)
                }
            }

            // Применяем transform из первого сегмента к композиции для сохранения ориентации
            if let transform = firstSegmentTransform {
                videoTrack.preferredTransform = transform
            }

            // Экспортируем объединенное видео
            let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "merged_\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: exportURL)

            guard
                let exportSession = AVAssetExportSession(
                    asset: composition, presetName: AVAssetExportPresetHighestQuality)
            else {
                completion(nil)
                return
            }

            exportSession.outputURL = exportURL
            exportSession.outputFileType = .mp4

            // Используем новый async API для iOS 18+, с fallback для старых версий
            if #available(iOS 18.0, *) {
                do {
                    try await exportSession.export(to: exportURL, as: .mp4)
                    let mergedData = try Data(contentsOf: exportURL)
                    try? FileManager.default.removeItem(at: exportURL)
                    completion(mergedData)
                } catch {
                    AppLogger.shared.error("Export failed: \(error.localizedDescription)", category: .general)
                    completion(nil)
                }
            } else {
                // Сохраняем exportURL для использования в closure
                let finalExportURL = exportURL
                // Используем nonisolated(unsafe) для безопасного доступа к exportSession в closure
                // Это безопасно, так как closure выполняется после завершения экспорта
                // и exportSession больше не используется после этого
                nonisolated(unsafe) let unsafeExportSession = exportSession
                unsafeExportSession.exportAsynchronously {
                    let status = unsafeExportSession.status
                    let errorMessage = unsafeExportSession.error?.localizedDescription ?? "unknown"

                    if status == .completed {
                        do {
                            let mergedData = try Data(contentsOf: finalExportURL)
                            try? FileManager.default.removeItem(at: finalExportURL)
                            completion(mergedData)
                        } catch {
                            AppLogger.shared.error("Failed to read merged video: \(error)", category: .general)
                            completion(nil)
                        }
                    } else {
                        AppLogger.shared.error("Export failed: \(errorMessage)", category: .general)
                        completion(nil)
                    }
                }
            }
        }
    }

    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    func switchCamera() {
        guard let session = captureSession else { return }

        // Если идет запись, нельзя переключать камеру напрямую
        // Нужно использовать другой подход - переключение происходит через изменение соединения
        guard !isRecording else {
            AppLogger.shared.warning("Cannot switch camera during recording", category: .general)
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Удаляем текущий видео вход
        if let videoInput = videoInput {
            session.removeInput(videoInput)
        }

        // Переключаем позицию камеры
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        isFrontCamera = (currentCameraPosition == .front)

        // Получаем новую камеру
        guard
            let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        else {
            print(
                "❌ VideoRecorderService: Failed to get video device for position \(currentCameraPosition)"
            )
            return
        }

        do {
            // Создаем новый видео вход
            let newVideoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(newVideoInput) {
                session.addInput(newVideoInput)
                self.videoInput = newVideoInput

                // Обновляем зеркалирование для preview layer
                if let previewLayer = previewLayerInstance,
                    let connection = previewLayer.connection, connection.isVideoMirroringSupported
                {
                    connection.automaticallyAdjustsVideoMirroring = false
                    // Зеркалим только для фронтальной камеры
                    connection.isVideoMirrored = (currentCameraPosition == .front)
                }

                print(
                    "✅ VideoRecorderService: Camera switched to \(currentCameraPosition == .front ? "front" : "back")"
                )
            } else {
                AppLogger.shared.error("Cannot add new video input", category: .general)
            }
        } catch {
            AppLogger.shared.error("Failed to create video input: \(error)", category: .general)
        }
    }

    func switchCameraDuringRecording() {
        // AVFoundation не позволяет менять входы камеры во время активной записи
        // Для переключения камеры нужно временно остановить запись, переключить и продолжить
        guard let session = captureSession,
            let output = videoOutput,
            isRecording,
            !isWaitingForSegmentCompletion,
            let currentURL = recordingURL
        else {
            AppLogger.shared.warning("Cannot switch camera - recording not ready", category: .general)
            return
        }

        // Сохраняем текущую длительность
        let savedDuration = recordingDuration

        // Устанавливаем флаг ожидания
        isWaitingForSegmentCompletion = true

        // Сохраняем callback для начала следующего сегмента
        pendingSegmentStart = { [weak self] in
            guard let self = self else { return }

            // Переключаем камеру
            session.beginConfiguration()

            // Удаляем текущий видео вход
            if let videoInput = self.videoInput {
                session.removeInput(videoInput)
            }

            // Переключаем позицию камеры
            let newPosition: AVCaptureDevice.Position =
                self.currentCameraPosition == .front ? .back : .front

            // Получаем новую камеру
            guard
                let newVideoDevice = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: newPosition)
            else {
                session.commitConfiguration()
                self.isWaitingForSegmentCompletion = false
                AppLogger.shared.error("Failed to get new video device", category: .general)
                return
            }

            do {
                let newVideoInput = try AVCaptureDeviceInput(device: newVideoDevice)
                if session.canAddInput(newVideoInput) {
                    session.addInput(newVideoInput)
                    self.videoInput = newVideoInput
                    self.currentCameraPosition = newPosition

                    // Обновляем зеркалирование для preview layer
                    if let previewLayer = self.previewLayerInstance,
                        let previewConnection = previewLayer.connection,
                        previewConnection.isVideoMirroringSupported
                    {
                        previewConnection.automaticallyAdjustsVideoMirroring = false
                        previewConnection.isVideoMirrored = (self.currentCameraPosition == .front)
                    }

                    session.commitConfiguration()

                    // Продолжаем запись в новый сегмент
                    self.continueRecordingAfterSwitch(
                        currentURL: currentURL, savedDuration: savedDuration)

                    print(
                        "✅ VideoRecorderService: Camera switched to \(self.currentCameraPosition == .front ? "front" : "back") during recording"
                    )
                } else {
                    session.commitConfiguration()
                    self.isWaitingForSegmentCompletion = false
                    AppLogger.shared.error("Cannot add new video input", category: .general)
                }
            } catch {
                session.commitConfiguration()
                self.isWaitingForSegmentCompletion = false
                AppLogger.shared.error("Failed to switch camera: \(error)", category: .general)
            }
        }

        // Останавливаем текущую запись - делегат вызовет pendingSegmentStart
        output.stopRecording()
    }

    private func continueRecordingAfterSwitch(currentURL: URL, savedDuration: TimeInterval) {
        guard let output = videoOutput else {
            isWaitingForSegmentCompletion = false
            return
        }

        // Проверяем, не идет ли уже запись
        if output.isRecording {
            AppLogger.shared.warning("Output is already recording, waiting...", category: .general)
            // Пытаемся снова через небольшую задержку
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.continueRecordingAfterSwitch(
                    currentURL: currentURL, savedDuration: savedDuration)
            }
            return
        }

        // Устанавливаем ориентацию для нового сегмента
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                let rotationAngle = getVideoRotationAngle()
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
            } else {
                let videoOrientation = getVideoOrientation()
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
            }
        }

        // Создаем новый файл для второго сегмента
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
            0]
        let segmentURL = documentsPath.appendingPathComponent(
            "video_segment_\(UUID().uuidString).mp4")

        // Удаляем файл если существует
        try? FileManager.default.removeItem(at: segmentURL)

        // Добавляем сегмент в список
        recordingSegments.append(segmentURL)
        segmentStartTime = savedDuration

        // Начинаем запись нового сегмента
        output.startRecording(to: segmentURL, recordingDelegate: self)

        // Обновляем recordingURL для отслеживания текущего сегмента
        recordingURL = segmentURL

        // Сбрасываем флаг ожидания
        isWaitingForSegmentCompletion = false

        // Восстанавливаем таймер
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            // Обновляем длительность: время начала сегмента + прошедшее время
            self.recordingDuration =
                self.segmentStartTime + (self.recordingDuration - self.segmentStartTime)
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecorderService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection], error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Если это завершение сегмента во время переключения камеры
            if self.isWaitingForSegmentCompletion {
                // Вызываем callback для начала следующего сегмента
                self.pendingSegmentStart?()
                self.pendingSegmentStart = nil
                return
            }

            // Если это обычное завершение записи
            self.isRecording = false
            self.recordingDuration = 0

            if let error = error {
                AppLogger.shared.error("Recording error: \(error)", category: .general)
                self.isWaitingForSegmentCompletion = false
                self.pendingSegmentStart = nil
                self.stopRecordingCompletion?(nil)
                self.stopRecordingCompletion = nil
                return
            }

            // Если есть несколько сегментов, объединяем их
            if self.recordingSegments.count > 1 {
                self.mergeVideoSegments { mergedData in
                    self.stopRecordingCompletion?(mergedData)
                    // Удаляем временные файлы
                    for segmentURL in self.recordingSegments {
                        try? FileManager.default.removeItem(at: segmentURL)
                    }
                    self.recordingSegments.removeAll()
                    self.stopRecordingCompletion = nil
                    self.recordingURL = nil
                }
            } else {
                // Читаем данные видео из одного файла
                do {
                    let videoData = try Data(contentsOf: outputFileURL)
                    self.stopRecordingCompletion?(videoData)
                    // Удаляем временный файл после чтения
                    try? FileManager.default.removeItem(at: outputFileURL)
                    self.recordingSegments.removeAll()
                } catch {
                    AppLogger.shared.error("Failed to read video data: \(error)", category: .general)
                    self.stopRecordingCompletion?(nil)
                }

                self.stopRecordingCompletion = nil
                self.recordingURL = nil
            }
        }
    }
}
