//
//  NotificationService.swift
//  Hohma
//
//  Notification Service Extension для обработки изображений в push-уведомлениях
//

import UIKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            AppLogger.shared.error("Failed to create mutable content", category: .general)
            contentHandler(request.content)
            return
        }

        // Логируем весь payload для отладки
        let userInfo = bestAttemptContent.userInfo
        AppLogger.shared.debug("Received notification", category: .general)
        AppLogger.shared.debug("UserInfo keys: \(userInfo.keys)", category: .general)
        AppLogger.shared.debug("Full userInfo: \(userInfo)", category: .general)

        // Пытаемся получить URL изображения из разных возможных ключей
        let imageURLString =
            userInfo["image-url"] as? String ?? userInfo["image"] as? String ?? userInfo[
                "attachment-url"] as? String ?? userInfo["media-url"] as? String

        guard let imageURLString = imageURLString,
            !imageURLString.isEmpty
        else {
            AppLogger.shared.error("No image URL found in notification payload", category: .general)
            AppLogger.shared.debug("Available keys: \(userInfo.keys)", category: .general)
            contentHandler(bestAttemptContent)
            return
        }

        // Проверяем, что URL абсолютный
        if !imageURLString.hasPrefix("http://") && !imageURLString.hasPrefix("https://") {
            // Если URL относительный, логируем предупреждение
            // URL должен быть абсолютным с сервера
            AppLogger.shared.warning("Image URL is not absolute: \(imageURLString)", category: .general)
        }

        guard let imageURL = URL(string: imageURLString) else {
            AppLogger.shared.error("Invalid image URL: \(imageURLString)", category: .general)
            contentHandler(bestAttemptContent)
            return
        }

        AppLogger.shared.info("Found image URL: \(imageURLString)", category: .general)

        // Загружаем изображение и добавляем его к уведомлению
        downloadImage(from: imageURL) { [weak self] attachment in
            guard let self = self,
                let bestAttemptContent = self.bestAttemptContent
            else {
                contentHandler(bestAttemptContent)
                return
            }

            if let attachment = attachment {
                AppLogger.shared.debug("Image attachment created successfully", category: .general)
                bestAttemptContent.attachments = [attachment]
            } else {
                AppLogger.shared.warning("Failed to create image attachment", category: .general)
            }

            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Вызываем contentHandler с текущим содержимым, если загрузка не завершилась
        if let contentHandler = contentHandler,
            let bestAttemptContent = bestAttemptContent
        {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadImage(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        AppLogger.shared.debug("Starting download from URL: \(url.absoluteString)", category: .general)

        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            if let error = error {
                AppLogger.shared.error("Download error: \(error.localizedDescription)", category: .general)
                AppLogger.shared.error("Error details: \(error)", category: .general)
                completion(nil)
                return
            }

            guard let location = location else {
                AppLogger.shared.error("No file location returned", category: .general)
                if let httpResponse = response as? HTTPURLResponse {
                    AppLogger.shared.error("HTTP status code: \(httpResponse.statusCode)", category: .general)
                }
                completion(nil)
                return
            }

            AppLogger.shared.info("File downloaded to: \(location.path)", category: .general)

            // Определяем тип контента из Content-Type или URL
            var contentType: String? = nil
            if let httpResponse = response as? HTTPURLResponse {
                contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            }

            let urlExtension = url.pathExtension.lowercased()
            let isSVG = urlExtension == "svg" || contentType?.contains("svg") == true
            let isWebP = urlExtension == "webp" || contentType?.contains("webp") == true

            // Если это SVG, конвертируем в PNG
            if isSVG {
                AppLogger.shared.debug("Detected SVG, converting to PNG", category: .general)
                self.convertSVGToPNG(from: location, completion: completion)
                return
            }

            // Если это WebP, конвертируем в PNG (iOS не поддерживает WebP в уведомлениях)
            if isWebP {
                AppLogger.shared.debug("Detected WebP, converting to PNG", category: .general)
                self.convertWebPToPNG(from: location, completion: completion)
                return
            }

            // Определяем расширение файла
            var fileExtension = urlExtension
            if fileExtension.isEmpty {
                // Пытаемся определить тип из Content-Type
                if let contentType = contentType {
                    if contentType.contains("jpeg") || contentType.contains("jpg") {
                        fileExtension = "jpg"
                    } else if contentType.contains("png") {
                        fileExtension = "png"
                    } else if contentType.contains("gif") {
                        fileExtension = "gif"
                    }
                }
                // По умолчанию используем jpg
                if fileExtension.isEmpty {
                    fileExtension = "jpg"
                }
            }

            // Создаем уникальное имя файла
            let fileName = "\(UUID().uuidString).\(fileExtension)"
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFile = tempDirectory.appendingPathComponent(fileName)

            do {
                // Перемещаем загруженный файл в временную директорию
                try FileManager.default.moveItem(at: location, to: tempFile)

                // Создаем attachment
                let attachment = try UNNotificationAttachment(
                    identifier: fileName,
                    url: tempFile,
                    options: nil
                )

                AppLogger.shared.info("Image attachment created: \(fileName)", category: .general)
                completion(attachment)
            } catch {
                print(
                    "❌ NotificationService: Failed to create attachment: \(error.localizedDescription)"
                )
                completion(nil)
            }
        }

        task.resume()
    }

    private func convertSVGToPNG(
        from location: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        // Читаем SVG данные
        guard let svgData = try? Data(contentsOf: location) else {
            AppLogger.shared.error("Failed to read SVG data", category: .general)
            completion(nil)
            return
        }

        // UIImage не поддерживает SVG напрямую
        // Попробуем загрузить SVG как изображение через альтернативный метод
        // Для Telegram аватаров SVG часто содержит встроенное изображение

        // Попробуем создать изображение из данных
        // Если это не сработает, вернем nil
        guard let image = UIImage(data: svgData) else {
            AppLogger.shared.warning("SVG cannot be directly converted by UIImage", category: .general)
            print(
                "⚠️ NotificationService: SVG conversion requires external library or server-side processing"
            )
            // Для SVG из Telegram можно попробовать заменить расширение на .png в URL
            // Но это не гарантирует работу
            completion(nil)
            return
        }

        // Конвертируем UIImage в PNG
        guard let pngData = image.pngData() else {
            AppLogger.shared.error("Failed to convert image to PNG", category: .general)
            completion(nil)
            return
        }

        // Сохраняем PNG во временный файл
        let fileName = "\(UUID().uuidString).png"
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: tempFile)

            let attachment = try UNNotificationAttachment(
                identifier: fileName,
                url: tempFile,
                options: nil
            )

            AppLogger.shared.info("SVG converted to PNG: \(fileName)", category: .general)
            completion(attachment)
        } catch {
            AppLogger.shared.error("Failed to save PNG: \(error.localizedDescription)", category: .general)
            completion(nil)
        }
    }

    private func convertWebPToPNG(
        from location: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        // Читаем WebP данные
        guard let webpData = try? Data(contentsOf: location),
            let image = UIImage(data: webpData)
        else {
            AppLogger.shared.error("Failed to read or decode WebP data", category: .general)
            completion(nil)
            return
        }

        // Конвертируем в PNG
        guard let pngData = image.pngData() else {
            AppLogger.shared.error("Failed to convert WebP to PNG", category: .general)
            completion(nil)
            return
        }

        // Сохраняем PNG во временный файл
        let fileName = "\(UUID().uuidString).png"
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: tempFile)

            let attachment = try UNNotificationAttachment(
                identifier: fileName,
                url: tempFile,
                options: nil
            )

            AppLogger.shared.info("WebP converted to PNG: \(fileName)", category: .general)
            completion(attachment)
        } catch {
            AppLogger.shared.error("Failed to save PNG: \(error.localizedDescription)", category: .general)
            completion(nil)
        }
    }
}
