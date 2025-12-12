//
//  ImageUploadButton.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Inject
import PhotosUI
import SwiftUI

struct ImageUploadButton: View {
    @ObserveInjection var inject
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success

    let onImageUploaded: (String) -> Void

    enum AlertType {
        case success, error
    }

    var body: some View {
        VStack(spacing: 12) {
            // Превью изображения
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }

            // Кнопка выбора изображения
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Выбрать фото")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("AccentColor"))
                .cornerRadius(8)
            }
            .disabled(isUploading)

            // Кнопка загрузки
            if selectedImage != nil {
                Button(action: uploadImage) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                        Text(isUploading ? "Загрузка..." : "Загрузить")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isUploading ? Color.gray : Color.green)
                    .cornerRadius(8)
                }
                .disabled(isUploading)
            }

            // Прогресс загрузки
            if isUploading {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 4)
                    .padding(.horizontal)
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                {
                    selectedImage = image
                }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {}
        }
        .enableInjection()
    }

    private func uploadImage() {
        guard let image = selectedImage else { return }

        isUploading = true
        uploadProgress = 0

        Task {
            do {
                // Симулируем прогресс загрузки
                for i in 1...10 {
                    try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 секунды
                    await MainActor.run {
                        uploadProgress = Double(i) / 10.0
                    }
                }

                // Загружаем изображение
                let fileURL = try await FileUploadService.shared.uploadImage(image)

                await MainActor.run {
                    isUploading = false
                    uploadProgress = 1.0
                    alertMessage = "Изображение успешно загружено!"
                    alertType = .success
                    showAlert = true

                    // Вызываем callback с URL загруженного файла
                    onImageUploaded(fileURL)
                }

            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadProgress = 0
                    alertMessage = "Ошибка загрузки: \(error.localizedDescription)"
                    alertType = .error
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    ImageUploadButton { fileURL in
        AppLogger.shared.debug("Загружен файл: \(fileURL)", category: .ui)
    }
    .padding()
    .appBackground()
}
