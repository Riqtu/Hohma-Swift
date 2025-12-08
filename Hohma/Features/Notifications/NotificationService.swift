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
            print("❌ NotificationService: Failed to create mutable content")
            contentHandler(request.content)
            return
        }

        // Логируем весь payload для отладки
        let userInfo = bestAttemptContent.userInfo
        print("📱 NotificationService: Received notification")
        print("📱 NotificationService: UserInfo keys: \(userInfo.keys)")
        print("📱 NotificationService: Full userInfo: \(userInfo)")

        // Пытаемся получить URL изображения из разных возможных ключей
        let imageURLString =
            userInfo["image-url"] as? String ?? userInfo["image"] as? String ?? userInfo[
                "attachment-url"] as? String ?? userInfo["media-url"] as? String

        guard let imageURLString = imageURLString,
            !imageURLString.isEmpty
        else {
            print("❌ NotificationService: No image URL found in notification payload")
            print("📱 NotificationService: Available keys: \(userInfo.keys)")
            contentHandler(bestAttemptContent)
            return
        }

        // Проверяем, что URL абсолютный
        if !imageURLString.hasPrefix("http://") && !imageURLString.hasPrefix("https://") {
            // Если URL относительный, логируем предупреждение
            // URL должен быть абсолютным с сервера
            print("⚠️ NotificationService: Image URL is not absolute: \(imageURLString)")
        }

        guard let imageURL = URL(string: imageURLString) else {
            print("❌ NotificationService: Invalid image URL: \(imageURLString)")
            contentHandler(bestAttemptContent)
            return
        }

        print("✅ NotificationService: Found image URL: \(imageURLString)")

        // Загружаем изображение и добавляем его к уведомлению
        downloadImage(from: imageURL) { [weak self] attachment in
            guard let self = self,
                let bestAttemptContent = self.bestAttemptContent
            else {
                contentHandler(bestAttemptContent)
                return
            }

            if let attachment = attachment {
                print("📱 NotificationService: Image attachment created successfully")
                bestAttemptContent.attachments = [attachment]
            } else {
                print("⚠️ NotificationService: Failed to create image attachment")
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
        print("📥 NotificationService: Starting download from URL: \(url.absoluteString)")

        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            if let error = error {
                print("❌ NotificationService: Download error: \(error.localizedDescription)")
                print("❌ NotificationService: Error details: \(error)")
                completion(nil)
                return
            }

            guard let location = location else {
                print("❌ NotificationService: No file location returned")
                if let httpResponse = response as? HTTPURLResponse {
                    print("❌ NotificationService: HTTP status code: \(httpResponse.statusCode)")
                }
                completion(nil)
                return
            }

            print("✅ NotificationService: File downloaded to: \(location.path)")

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
                print("📱 NotificationService: Detected SVG, converting to PNG")
                self.convertSVGToPNG(from: location, completion: completion)
                return
            }

            // Если это WebP, конвертируем в PNG (iOS не поддерживает WebP в уведомлениях)
            if isWebP {
                print("📱 NotificationService: Detected WebP, converting to PNG")
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

                print("✅ NotificationService: Image attachment created: \(fileName)")
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
            print("❌ NotificationService: Failed to read SVG data")
            completion(nil)
            return
        }

        // UIImage не поддерживает SVG напрямую
        // Попробуем загрузить SVG как изображение через альтернативный метод
        // Для Telegram аватаров SVG часто содержит встроенное изображение

        // Попробуем создать изображение из данных
        // Если это не сработает, вернем nil
        guard let image = UIImage(data: svgData) else {
            print("⚠️ NotificationService: SVG cannot be directly converted by UIImage")
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
            print("❌ NotificationService: Failed to convert image to PNG")
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

            print("✅ NotificationService: SVG converted to PNG: \(fileName)")
            completion(attachment)
        } catch {
            print("❌ NotificationService: Failed to save PNG: \(error.localizedDescription)")
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
            print("❌ NotificationService: Failed to read or decode WebP data")
            completion(nil)
            return
        }

        // Конвертируем в PNG
        guard let pngData = image.pngData() else {
            print("❌ NotificationService: Failed to convert WebP to PNG")
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

            print("✅ NotificationService: WebP converted to PNG: \(fileName)")
            completion(attachment)
        } catch {
            print("❌ NotificationService: Failed to save PNG: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
