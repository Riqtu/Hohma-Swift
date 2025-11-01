//
//  FileUploadService.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Foundation
import UIKit

final class FileUploadService: TRPCServiceProtocol {
    static let shared = FileUploadService()
    private init() {}

    // MARK: - Get Presigned URL
    func getPresignedUrl(fileName: String, fileType: String) async throws -> PresignedUrlResponse {
        let body = [
            "fileName": fileName,
            "fileType": fileType,
        ]

        return try await trpcService.executePOST(endpoint: "s3.getPresignedUrl", body: body)
    }

    // MARK: - Upload File to S3
    func uploadFileToS3(uploadURL: String, fileData: Data, mimeType: String? = nil) async throws {
        guard let url = URL(string: uploadURL) else {
            throw NSError(
                domain: "URLError", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Неверный URL для загрузки"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = fileData

        // Используем переданный MIME тип или определяем на основе данных
        let contentType = mimeType ?? getMimeType(from: fileData)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

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
        try await uploadFileToS3(uploadURL: presignedResponse.uploadURL, fileData: imageData, mimeType: fileType)

        // Формируем URL загруженного файла из presigned URL
        let fileURL = presignedResponse.uploadURL.components(separatedBy: "?")[0]
        return fileURL
    }

    // MARK: - Upload Any File
    func uploadFile(fileData: Data, fileName: String, mimeType: String) async throws -> String {
        // Получаем presigned URL
        let presignedResponse = try await getPresignedUrl(fileName: fileName, fileType: mimeType)
        
        // Загружаем файл в S3
        try await uploadFileToS3(uploadURL: presignedResponse.uploadURL, fileData: fileData, mimeType: mimeType)
        
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
    
    static func getMimeType(for fileExtension: String) -> String {
        let lowercased = fileExtension.lowercased()
        switch lowercased {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "txt": return "text/plain"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Response Models
struct PresignedUrlResponse: Codable {
    let uploadURL: String

    enum CodingKeys: String, CodingKey {
        case uploadURL = "uploadURL"
    }
}
