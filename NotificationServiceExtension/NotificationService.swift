//
//  NotificationService.swift
//  Hohma
//
//  Notification Service Extension для обработки изображений в push-уведомлениях
//

import OSLog
import UIKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "riqtu.Hohma", category: "NotificationService")

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            Self.logger.error("Failed to create mutable content")
            contentHandler(request.content)
            return
        }

        // Логируем весь payload для отладки
        let userInfo = bestAttemptContent.userInfo
        Self.logger.info("Received notification")
        Self.logger.debug("UserInfo keys: \(userInfo.keys.description)")
        #if DEBUG
            Self.logger.debug("Full userInfo: \(userInfo.description)")
        #endif

        // Пытаемся получить URL изображения из разных возможных ключей
        let imageURLString =
            userInfo["image-url"] as? String ?? userInfo["image"] as? String ?? userInfo[
                "attachment-url"] as? String ?? userInfo["media-url"] as? String

        guard let imageURLString = imageURLString,
            !imageURLString.isEmpty
        else {
            Self.logger.error("No image URL found in notification payload")
            Self.logger.debug("Available keys: \(userInfo.keys.description)")
            contentHandler(bestAttemptContent)
            return
        }

        // Проверяем, что URL абсолютный
        if !imageURLString.hasPrefix("http://") && !imageURLString.hasPrefix("https://") {
            // Если URL относительный, логируем предупреждение
            // URL должен быть абсолютным с сервера
            Self.logger.warning("Image URL is not absolute: \(imageURLString)")
        }

        guard let imageURL = URL(string: imageURLString) else {
            Self.logger.error("Invalid image URL: \(imageURLString)")
            contentHandler(bestAttemptContent)
            return
        }

        Self.logger.info("Found image URL: \(imageURLString)")

        // Загружаем изображение и добавляем его к уведомлению
        // Используем маленький размер (30x30) для отображения слева рядом с иконкой приложения
        downloadImage(from: imageURL) { [weak self] attachment in
            guard let self = self,
                let bestAttemptContent = self.bestAttemptContent
            else {
                contentHandler(bestAttemptContent)
                return
            }

            if let attachment = attachment {
                Self.logger.info("Image attachment created successfully")

                // Устанавливаем threadIdentifier для группировки уведомлений
                if let chatId = userInfo["chatId"] as? String {
                    bestAttemptContent.threadIdentifier = chatId
                }

                // Добавляем attachment
                // iOS может показать маленький квадратный attachment слева рядом с иконкой приложения
                bestAttemptContent.attachments = [attachment]
            } else {
                Self.logger.warning("Failed to create image attachment")
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
        Self.logger.debug("Starting download from URL: \(url.absoluteString)")

        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            if let error = error {
                Self.logger.error("Download error: \(error.localizedDescription)")
                Self.logger.error("Error details: \(error.localizedDescription)")
                completion(nil)
                return
            }

            // Логируем HTTP ответ
            if let httpResponse = response as? HTTPURLResponse {
                Self.logger.debug("HTTP status code: \(httpResponse.statusCode)")
                Self.logger.debug(
                    "Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")"
                )
                Self.logger.debug(
                    "Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")"
                )
            }

            guard let location = location else {
                Self.logger.error("No file location returned")
                if let httpResponse = response as? HTTPURLResponse {
                    Self.logger.error("HTTP status code: \(httpResponse.statusCode)")
                }
                completion(nil)
                return
            }

            Self.logger.info("File downloaded to: \(location.path)")

            // Проверяем размер файла
            if let attributes = try? FileManager.default.attributesOfItem(atPath: location.path),
                let fileSize = attributes[.size] as? Int64
            {
                Self.logger.debug("File size: \(fileSize) bytes")
            }

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
                Self.logger.info("Detected SVG, converting to PNG")
                self.convertSVGToPNG(from: location, completion: completion)
                return
            }

            // Если это WebP, конвертируем в PNG (iOS не поддерживает WebP в уведомлениях)
            if isWebP {
                Self.logger.info("Detected WebP, converting to PNG")
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

            Self.logger.debug("Detected file extension: \(fileExtension)")
            Self.logger.debug("Content-Type: \(contentType ?? "unknown")")

            // Проверяем, что файл действительно существует и читается
            guard FileManager.default.fileExists(atPath: location.path) else {
                Self.logger.error("Downloaded file does not exist at path: \(location.path)")
                completion(nil)
                return
            }

            // Для PNG файлов проверяем, что это действительно изображение
            if fileExtension == "png" || contentType?.contains("png") == true {
                // Пытаемся загрузить как UIImage для проверки
                if let imageData = try? Data(contentsOf: location),
                    let image = UIImage(data: imageData)
                {
                    Self.logger.debug(
                        "PNG file is valid image, size: \(image.size.debugDescription)")
                } else {
                    Self.logger.warning("PNG file exists but cannot be loaded as UIImage")
                }
            }

            // Обрабатываем изображение для thumbnail (отображение слева вместо иконки)
            // iOS автоматически использует первое attachment как thumbnail, если оно подходящего размера
            guard let imageData = try? Data(contentsOf: location),
                let image = UIImage(data: imageData)
            else {
                Self.logger.error("Failed to load image data")
                completion(nil)
                return
            }

            // Создаем квадратное изображение для thumbnail слева (как в Telegram)
            // iOS показывает thumbnail слева только для очень маленьких квадратных изображений
            // Размер 30x30 - оптимальный размер для отображения слева рядом с иконкой приложения
            // В Telegram используется маленький аватар (около 30px), который отображается слева вместе с иконкой
            let thumbnailSize: CGFloat = 30
            let processedImage = self.processImageForThumbnail(image, size: thumbnailSize)

            guard let processedImageData = processedImage.pngData() else {
                Self.logger.error("Failed to convert processed image to PNG")
                completion(nil)
                return
            }

            // Создаем уникальное имя файла
            let fileName = "\(UUID().uuidString).png"
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFile = tempDirectory.appendingPathComponent(fileName)

            do {
                // Сохраняем обработанное изображение
                try processedImageData.write(to: tempFile)

                Self.logger.debug("Processed image saved to: \(tempFile.path)")
                Self.logger.debug("Image size: \(processedImage.size.debugDescription)")

                // Создаем attachment с опциями для thumbnail слева (как в Telegram)
                // Используем фиксированный identifier "thumbnail" для iOS
                // iOS автоматически показывает маленькие квадратные изображения слева
                let attachment = try UNNotificationAttachment(
                    identifier: "thumbnail",
                    url: tempFile,
                    options: [
                        UNNotificationAttachmentOptionsTypeHintKey: "public.png",
                        // Указываем, что это thumbnail для отображения слева
                        UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
                    ]
                )

                Self.logger.info("Image attachment created for thumbnail: \(fileName)")
                completion(attachment)
            } catch {
                Self.logger.error("Failed to create attachment: \(error.localizedDescription)")
                Self.logger.error("Error: \(error.localizedDescription)")
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
            Self.logger.error("Failed to read SVG data")
            completion(nil)
            return
        }

        // UIImage не поддерживает SVG напрямую
        // Попробуем загрузить SVG как изображение через альтернативный метод
        // Для Telegram аватаров SVG часто содержит встроенное изображение

        // Попробуем создать изображение из данных
        // Если это не сработает, вернем nil
        guard let image = UIImage(data: svgData) else {
            Self.logger.warning("SVG cannot be directly converted by UIImage")
            Self.logger.warning(
                "SVG conversion requires external library or server-side processing")
            // Для SVG из Telegram можно попробовать заменить расширение на .png в URL
            // Но это не гарантирует работу
            completion(nil)
            return
        }

        // Обрабатываем изображение для thumbnail слева (как в Telegram)
        // Размер 30x30 - оптимальный размер для отображения слева рядом с иконкой приложения
        let thumbnailSize: CGFloat = 30
        let processedImage = self.processImageForThumbnail(image, size: thumbnailSize)

        // Конвертируем обработанное изображение в PNG
        guard let pngData = processedImage.pngData() else {
            Self.logger.error("Failed to convert processed image to PNG")
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
                identifier: "thumbnail",
                url: tempFile,
                options: [
                    UNNotificationAttachmentOptionsTypeHintKey: "public.png",
                    UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
                ]
            )

            Self.logger.info("SVG converted to PNG for thumbnail: \(fileName)")
            completion(attachment)
        } catch {
            Self.logger.error("Failed to save PNG: \(error.localizedDescription)")
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
            Self.logger.error("Failed to read or decode WebP data")
            completion(nil)
            return
        }

        // Обрабатываем изображение для thumbnail слева (как в Telegram)
        // Размер 30x30 - оптимальный размер для отображения слева рядом с иконкой приложения
        let thumbnailSize: CGFloat = 30
        let processedImage = self.processImageForThumbnail(image, size: thumbnailSize)

        // Конвертируем обработанное изображение в PNG
        guard let pngData = processedImage.pngData() else {
            Self.logger.error("Failed to convert processed image to PNG")
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
                identifier: "thumbnail",
                url: tempFile,
                options: [
                    UNNotificationAttachmentOptionsTypeHintKey: "public.png",
                    UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
                ]
            )

            Self.logger.info("WebP converted to PNG for thumbnail: \(fileName)")
            completion(attachment)
        } catch {
            Self.logger.error("Failed to save PNG: \(error.localizedDescription)")
            completion(nil)
        }
    }

    /// Обрабатывает изображение для thumbnail (отображение слева вместо иконки приложения)
    /// Делает изображение квадратным и нужного размера
    private func processImageForThumbnail(_ image: UIImage, size: CGFloat) -> UIImage {
        let targetSize = CGSize(width: size, height: size)

        // Вычисляем размер для обрезки (берем меньшую сторону)
        let imageSize = image.size
        let minSide = min(imageSize.width, imageSize.height)
        let cropRect = CGRect(
            x: (imageSize.width - minSide) / 2,
            y: (imageSize.height - minSide) / 2,
            width: minSide,
            height: minSide
        )

        // Обрезаем изображение до квадрата
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            Self.logger.warning("Failed to crop image, using original")
            return image
        }

        let croppedImage = UIImage(
            cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Масштабируем до нужного размера
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? croppedImage

        Self.logger.debug(
            "Processed image for thumbnail: original size \(imageSize.debugDescription), target size \(targetSize.debugDescription)"
        )

        return scaledImage
    }
}
