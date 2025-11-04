//
//  VideoRecordOverlayView.swift
//  Hohma
//
//  Created by Assistant on 01.11.2025.
//

import AVFoundation
import Inject
import SwiftUI

struct VideoRecordOverlayView: View {
    @ObserveInjection var inject
    let duration: TimeInterval
    let previewLayer: CALayer?
    let isFrontCamera: Bool
    let showControls: Bool  // Показывать ли кнопки управления
    let onCancel: () -> Void
    let onSwitchCamera: () -> Void
    let onSend: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let circleSize = min(geometry.size.width * 0.7, geometry.size.height * 0.5, 300)

            ZStack {
                // Размытый полупрозрачный фон
                Rectangle()
                    .fill(Material.thinMaterial)
                    .overlay(
                        Color.black.opacity(0.2)
                    )
                    .ignoresSafeArea()

                // Круглый preview камеры в центре
                if let previewLayer = previewLayer {
                    CameraPreviewLayer(layer: previewLayer, isFrontCamera: isFrontCamera)
                        .frame(width: circleSize, height: circleSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        )
                        .shadow(radius: 20)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: circleSize, height: circleSize)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }

                // Подсказки при начале записи (если кнопки управления не показаны)
                if !showControls {
                    VStack {
                        HStack(spacing: 40) {
                            // Подсказка: свайп влево - отмена
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Отменить")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Spacer()

                            // Подсказка: свайп вверх - управление
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Управление")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 50)
                        .padding(.top, 60)

                        Spacer()
                    }
                }

                // Затемнение сверху
                VStack {

                    Spacer()

                    // Затемнение снизу
                    VStack {
                        Spacer()

                        // Длительность записи (всегда видна)
                        Text(formatTime(duration))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(12)
                            .padding(.bottom, showControls ? 20 : 100)

                        // Кнопки управления (только при showControls == true)
                        if showControls {
                            HStack(spacing: 20) {
                                // Кнопка отмены
                                Button(action: onCancel) {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Circle())
                                }

                                Spacer()

                                // Кнопка переключения камеры
                                Button(action: onSwitchCamera) {
                                    Image(systemName: "camera.rotate")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }

                                Spacer()

                                // Кнопка отправки
                                Button(action: onSend) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.accentColor.opacity(0.9))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 50)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear, Color.black.opacity(showControls ? 0.7 : 0.3),
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
        .enableInjection()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Camera Preview Layer
struct CameraPreviewLayer: UIViewRepresentable {
    let layer: CALayer
    let isFrontCamera: Bool

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        if let previewLayer = layer as? AVCaptureVideoPreviewLayer {
            view.setPreviewLayer(previewLayer)
            view.updateMirroring(isFront: isFrontCamera)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let previewLayer = layer as? AVCaptureVideoPreviewLayer {
            uiView.setPreviewLayer(previewLayer)
            uiView.updateMirroring(isFront: isFrontCamera)
        }
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isFrontCamera = true  // По умолчанию фронтальная камера

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        // Удаляем старый layer если есть
        previewLayer?.removeFromSuperlayer()

        previewLayer = layer
        layer.removeFromSuperlayer()
        self.layer.addSublayer(layer)

        // Устанавливаем videoGravity для квадратного обрезания
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds

        // Обновляем зеркалирование в зависимости от позиции камеры
        updateMirroring()
    }

    func updateMirroring(isFront: Bool) {
        isFrontCamera = isFront
        updateMirroring()
    }

    private func updateMirroring() {
        guard let previewLayer = previewLayer,
            let connection = previewLayer.connection,
            connection.isVideoMirroringSupported
        else {
            return
        }

        // Отключаем автоматическое зеркалирование перед ручной установкой
        connection.automaticallyAdjustsVideoMirroring = false
        // Зеркалим только для фронтальной камеры
        connection.isVideoMirrored = isFrontCamera
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Обновляем frame preview layer - квадратный для круга
        let size = min(bounds.width, bounds.height)
        let x = (bounds.width - size) / 2
        let y = (bounds.height - size) / 2
        previewLayer?.frame = CGRect(x: x, y: y, width: size, height: size)
    }
}
