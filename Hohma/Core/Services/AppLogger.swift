//
//  AppLogger.swift
//  Hohma
//
//  Created by Artem Vydro on 27.01.2025.
//

import Foundation
import OSLog

// MARK: - DateFormatter Extension

extension DateFormatter {
    fileprivate static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

/// Централизованная система логирования для приложения
/// Использует os.log для нативного логирования в iOS
final class AppLogger {
    // MARK: - Singleton

    static let shared = AppLogger()
    private init() {}

    // MARK: - Log Categories

    enum Category: String {
        case network = "Network"
        case auth = "Authentication"
        case socket = "SocketIO"
        case ui = "UI"
        case cache = "Cache"
        case keychain = "Keychain"
        case general = "General"
    }

    // MARK: - Log Levels

    enum Level {
        case debug
        case info
        case warning
        case error
        case fault

        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .fault:
                return .fault
            }
        }

        var emoji: String {
            switch self {
            case .debug:
                return "🔍"
            case .info:
                return "ℹ️"
            case .warning:
                return "⚠️"
            case .error:
                return "❌"
            case .fault:
                return "💥"
            }
        }
    }

    // MARK: - Private Properties

    private let subsystem = Bundle.main.bundleIdentifier ?? "riqtu.Hohma"

    /// Включить вывод в консоль (stdout/stderr) для просмотра в терминале
    /// По умолчанию включено в DEBUG режиме
    var enableConsoleOutput: Bool = {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }()

    private func logger(for category: Category) -> Logger {
        return Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// Выводит сообщение в консоль (для терминала)
    private func printToConsole(_ message: String, level: Level, category: Category) {
        guard enableConsoleOutput else { return }
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let output = "[\(timestamp)] \(level.emoji) [\(category.rawValue)] \(message)"

        switch level {
        case .error, .fault:
            // Ошибки в stderr
            fputs(output + "\n", stderr)
        default:
            // Остальное в stdout
            print(output)
        }
    }

    // MARK: - Public Logging Methods

    /// Логирует debug сообщение (только в DEBUG режиме)
    func debug(
        _ message: String, category: Category = .general, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            let logMessage = "\(fileName):\(line) \(function) - \(message)"
            logger(for: category).log(level: .debug, "\(Level.debug.emoji) \(logMessage)")
            printToConsole(logMessage, level: .debug, category: category)
        #endif
    }

    /// Логирует info сообщение
    func info(
        _ message: String, category: Category = .general, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(fileName):\(line) \(function) - \(message)"
        logger(for: category).log(level: .info, "\(Level.info.emoji) \(logMessage)")
        printToConsole(logMessage, level: .info, category: category)
    }

    /// Логирует warning сообщение
    func warning(
        _ message: String, category: Category = .general, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(fileName):\(line) \(function) - \(message)"
        logger(for: category).log(level: .default, "\(Level.warning.emoji) \(logMessage)")
        printToConsole(logMessage, level: .warning, category: category)
    }

    /// Логирует error сообщение
    func error(
        _ message: String, error: Error? = nil, category: Category = .general, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "\(fileName):\(line) \(function) - \(message)"
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        logger(for: category).log(level: .error, "\(Level.error.emoji) \(logMessage)")
        printToConsole(logMessage, level: .error, category: category)
    }

    /// Логирует fault (критическую ошибку)
    func fault(
        _ message: String, error: Error? = nil, category: Category = .general, file: String = #file,
        function: String = #function, line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        var logMessage = "\(fileName):\(line) \(function) - \(message)"
        if let error = error {
            logMessage += " | Error: \(error.localizedDescription)"
        }
        logger(for: category).log(level: .fault, "\(Level.fault.emoji) \(logMessage)")
        printToConsole(logMessage, level: .fault, category: category)
    }

    // MARK: - Convenience Methods

    /// Логирует сетевой запрос
    func logRequest(_ request: URLRequest, category: Category = .network) {
        #if DEBUG
            var logMessage =
                "→ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")"
            if let headers = request.allHTTPHeaderFields {
                logMessage += "\nHeaders: \(headers)"
            }
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                logMessage += "\nBody: \(bodyString)"
            }
            debug(logMessage, category: category)
        #endif
    }

    /// Логирует сетевой ответ
    func logResponse(
        _ response: URLResponse?, data: Data?, error: Error? = nil, category: Category = .network
    ) {
        #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                var logMessage =
                    "← \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "unknown")"
                if let headers = httpResponse.allHeaderFields as? [String: Any] {
                    logMessage += "\nHeaders: \(headers)"
                }
                if let data = data, let dataString = String(data: data, encoding: .utf8),
                    dataString.count < 1000
                {
                    logMessage += "\nBody: \(dataString)"
                }
                if httpResponse.statusCode >= 400 {
                    self.error(logMessage, error: error, category: category)
                } else {
                    self.debug(logMessage, category: category)
                }
            } else if let error = error {
                self.error("Network request failed", error: error, category: category)
            }
        #endif
    }
}

// MARK: - Global Convenience Functions

/// Глобальные функции для удобства использования
func logDebug(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.debug(message, category: category)
}

func logInfo(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.info(message, category: category)
}

func logWarning(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.warning(message, category: category)
}

func logError(_ message: String, error: Error? = nil, category: AppLogger.Category = .general) {
    AppLogger.shared.error(message, error: error, category: category)
}

func logFault(_ message: String, error: Error? = nil, category: AppLogger.Category = .general) {
    AppLogger.shared.fault(message, error: error, category: category)
}
