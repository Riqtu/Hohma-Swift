import Foundation

enum AppError: Error {
    case networkError(String)
    case authenticationError(String)
    case dataError(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .authenticationError(let message):
            return "Ошибка авторизации: \(message)"
        case .dataError(let message):
            return "Ошибка данных: \(message)"
        case .invalidURL:
            return "Некорректный URL"
        }
    }
}
