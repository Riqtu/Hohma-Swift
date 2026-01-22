//
//  ErrorHandler.swift
//  Hohma
//
//  Created by Assistant on 27.01.2025.
//

import Foundation

/// Централизованный обработчик ошибок для конвертации технических ошибок
/// в понятные пользователю сообщения
final class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    /// Конвертирует любую ошибку в понятное пользователю сообщение
    /// - Parameter error: Ошибка для обработки
    /// - Returns: Понятное сообщение для пользователя
    func userFriendlyMessage(from error: Error) -> String {
        // Сначала проверяем наши кастомные типы ошибок
        if let appError = error as? AppError {
            return appError.errorDescription ?? "common.error".localized
        }
        
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? "error.network.general".localized
        }
        
        // Обрабатываем URLError (сетевые ошибки)
        if let urlError = error as? URLError {
            return messageForURLError(urlError)
        }
        
        // Обрабатываем DecodingError
        if let decodingError = error as? DecodingError {
            return messageForDecodingError(decodingError)
        }
        
        // Обрабатываем EncodingError
        if let encodingError = error as? EncodingError {
            return messageForEncodingError(encodingError)
        }
        
        // Обрабатываем NSError
        if let nsError = error as NSError? {
            return messageForNSError(nsError)
        }
        
        // Если есть localizedDescription, используем его
        let localizedDescription = error.localizedDescription
        if !localizedDescription.isEmpty && localizedDescription != "The operation couldn't be completed." {
            return localizedDescription
        }
        
        // Fallback на общее сообщение
        return "error.unknown".localized
    }
    
    /// Обрабатывает ошибку и логирует её для разработчиков
    /// - Parameters:
    ///   - error: Ошибка для обработки
    ///   - context: Контекст, где произошла ошибка
    ///   - category: Категория для логирования
    /// - Returns: Понятное сообщение для пользователя
    func handle(
        _ error: Error,
        context: String = #function,
        category: AppLogger.Category = .general
    ) -> String {
        // Логируем полную ошибку для разработчиков
        AppLogger.shared.error(
            "Error in \(context)",
            error: error,
            category: category
        )
        
        // Возвращаем понятное сообщение для пользователя
        return userFriendlyMessage(from: error)
    }
    
    // MARK: - Private Methods
    
    private func messageForURLError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "error.network.noConnection".localized
        case .timedOut:
            return "error.network.timeout".localized
        case .cannotFindHost, .cannotConnectToHost:
            return "error.network.serverConnection".localized
        case .badServerResponse:
            return "error.network.invalidResponse".localized
        case .cancelled:
            return "error.network.cancelled".localized
        case .userAuthenticationRequired:
            return "error.network.unauthorized".localized
        case .secureConnectionFailed:
            return "error.network.ssl".localized
        case .cannotLoadFromNetwork:
            return "error.network.dataLoad".localized
        case .dataNotAllowed:
            return "error.network.dataTransfer".localized
        default:
            return "error.network.general".localized
        }
    }
    
    private func messageForDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(_):
            AppLogger.shared.error("Decoding error: data corrupted", error: error, category: .general)
            return "error.data.general".localized
        case .keyNotFound(let key, _):
            AppLogger.shared.error("Decoding error: key '\(key.stringValue)' not found", error: error, category: .general)
            return "error.data.format".localized
        case .typeMismatch(let type, _):
            AppLogger.shared.error("Decoding error: type mismatch for \(type)", error: error, category: .general)
            return "error.data.format".localized
        case .valueNotFound(let type, _):
            AppLogger.shared.error("Decoding error: value not found for \(type)", error: error, category: .general)
            return "error.data.general".localized
        @unknown default:
            return "error.data.processing".localized
        }
    }
    
    private func messageForEncodingError(_ error: EncodingError) -> String {
        switch error {
        case .invalidValue(_, _):
            AppLogger.shared.error("Encoding error: invalid value", error: error, category: .general)
            return "error.data.preparation".localized
        @unknown default:
            return "error.data.preparation".localized
        }
    }
    
    private func messageForNSError(_ error: NSError) -> String {
        // Обрабатываем специфичные домены ошибок
        switch error.domain {
        case NSURLErrorDomain:
            // Создаем URLError из кода для обработки
            let urlErrorCode = URLError.Code(rawValue: error.code)
            let urlError = URLError(urlErrorCode)
            return messageForURLError(urlError)
            
        case NSCocoaErrorDomain:
            switch error.code {
            case NSFileReadNoSuchFileError, NSFileReadNoPermissionError:
                return "Файл не найден или нет доступа."
            case NSFileWriteFileExistsError:
                return "Файл уже существует."
            case NSFileWriteNoPermissionError:
                return "Нет прав на запись файла."
            default:
                return "Ошибка работы с файлом."
            }
            
        case NSPOSIXErrorDomain:
            return "Системная ошибка. Попробуйте позже."
            
        default:
            // Если есть понятное сообщение, используем его
            if let localizedDescription = error.userInfo[NSLocalizedDescriptionKey] as? String,
               !localizedDescription.isEmpty {
                return localizedDescription
            }
            return "Произошла ошибка. Попробуйте позже."
        }
    }
}

