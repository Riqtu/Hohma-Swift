//
//  FileUploadService.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Foundation
import UIKit

final class FileUploadService {
    static let shared = FileUploadService()
    private init() {}

    @MainActor private let networkManager = NetworkManager.shared
    private let baseURL: String = {
        return Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
            ?? "https://hohma.su/api/trpc"
    }()

    // MARK: - Get Presigned URL
    func getPresignedUrl(fileName: String, fileType: String) async throws -> PresignedUrlResponse {
        guard let authResultData = UserDefaults.standard.data(forKey: "authResult"),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            throw NSError(
                domain: "AuthError", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Не авторизован"])
        }

        guard let url = URL(string: "\(baseURL)/s3.getPresignedUrl") else {
            throw NSError(
                domain: "URLError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authResult.token)", forHTTPHeaderField: "Authorization")

        // Формируем tRPC запрос
        let requestBody = [
            "json": [
                "fileName": fileName,
                "fileType": fileType,
            ]
        ]

        guard let requestData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(
                domain: "JSONError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка кодирования запроса"])
        }

        request.httpBody = requestData

        return try await networkManager.request(request)
    }

    // MARK: - Upload File to S3
    func uploadFileToS3(uploadURL: String, imageData: Data) async throws {
        guard let url = URL(string: uploadURL) else {
            throw NSError(
                domain: "URLError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Неверный URL для загрузки"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = imageData

        // Определяем MIME тип на основе данных
        let mimeType = getMimeType(from: imageData)
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw NSError(
                domain: "UploadError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка загрузки файла"])
        }
    }

    // MARK: - Complete Upload Process
    func uploadImage(_ image: UIImage) async throws -> String {
        // Конвертируем изображение в JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(
                domain: "ImageError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка конвертации изображения"])
        }

        // Генерируем уникальное имя файла
        let fileName = "avatar_\(UUID().uuidString).jpg"
        let fileType = "image/jpeg"

        // Получаем presigned URL
        let presignedResponse = try await getPresignedUrl(fileName: fileName, fileType: fileType)

        // Загружаем файл в S3
        try await uploadFileToS3(uploadURL: presignedResponse.uploadURL, imageData: imageData)

        // Формируем URL загруженного файла из presigned URL
        let fileURL = presignedResponse.uploadURL.components(separatedBy: "?")[0]
        return fileURL
    }

    // MARK: - Helper Methods
    private func getMimeType(from data: Data) -> String {
        // Простая проверка на основе первых байт
        if data.count >= 2 {
            let bytes = [UInt8](data.prefix(2))
            if bytes == [0xFF, 0xD8] {
                return "image/jpeg"
            } else if bytes == [0x89, 0x50] {
                return "image/png"
            }
        }
        return "image/jpeg"  // По умолчанию
    }
}

// MARK: - Response Models
struct PresignedUrlResponse: Codable {
    let uploadURL: String

    enum CodingKeys: String, CodingKey {
        case uploadURL = "uploadURL"
    }
}
