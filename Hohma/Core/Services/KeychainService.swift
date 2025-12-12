//
//  KeychainService.swift
//  Hohma
//
//  Created by Artem Vydro on 27.01.2025.
//

import Foundation
import Security

/// Сервис для безопасного хранения чувствительных данных в Keychain
final class KeychainService {
    static let shared = KeychainService()

    private let serviceName: String
    private let accessGroup: String?

    private init() {
        // Используем bundle identifier как имя сервиса
        self.serviceName = Bundle.main.bundleIdentifier ?? "riqtu.Hohma"
        self.accessGroup = nil  // Можно настроить для App Groups если нужно
    }

    // MARK: - Keys

    private enum Key: String {
        case authResult = "authResult"
        case deviceToken = "deviceToken"
    }

    // MARK: - Auth Result Storage

    /// Сохраняет AuthResult в Keychain
    func saveAuthResult(_ authResult: AuthResult) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(authResult)
        try save(data: data, forKey: Key.authResult.rawValue)

        // Миграция: удаляем старые данные из UserDefaults
        UserDefaults.standard.removeObject(forKey: AppConstants.userDefaultsAuthResultKey)
    }

    /// Загружает AuthResult из Keychain
    func loadAuthResult() -> AuthResult? {
        guard let data = loadData(forKey: Key.authResult.rawValue) else {
            // Попытка миграции из UserDefaults (для существующих пользователей)
            return migrateFromUserDefaults()
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(AuthResult.self, from: data)
    }

    /// Удаляет AuthResult из Keychain
    func deleteAuthResult() throws {
        try delete(forKey: Key.authResult.rawValue)
    }

    /// Получает токен авторизации из Keychain
    var authToken: String? {
        return loadAuthResult()?.token
    }

    /// Получает текущего пользователя из Keychain
    var currentUser: AuthUser? {
        return loadAuthResult()?.user
    }

    // MARK: - Device Token Storage

    /// Сохраняет device token в Keychain
    func saveDeviceToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(data: data, forKey: Key.deviceToken.rawValue)

        // Миграция: удаляем старые данные из UserDefaults
        UserDefaults.standard.removeObject(forKey: AppConstants.userDefaultsDeviceTokenKey)
    }

    /// Загружает device token из Keychain
    func loadDeviceToken() -> String? {
        guard let data = loadData(forKey: Key.deviceToken.rawValue) else {
            // Попытка миграции из UserDefaults
            return migrateDeviceTokenFromUserDefaults()
        }
        return String(data: data, encoding: .utf8)
    }

    /// Удаляет device token из Keychain
    func deleteDeviceToken() throws {
        try delete(forKey: Key.deviceToken.rawValue)
    }

    // MARK: - Private Methods

    private func save(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // Удаляем существующую запись если есть
        SecItemDelete(query as CFDictionary)

        // Добавляем новую запись
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveError(status)
        }
    }

    private func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            AppLogger.shared.warning(
                "Failed to load data for key '\(key)', status: \(status)", category: .keychain)
            return nil
        }

        return result as? Data
    }

    private func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteError(status)
        }
    }

    // MARK: - Migration from UserDefaults

    /// Мигрирует AuthResult из UserDefaults в Keychain (одноразовая операция)
    private func migrateFromUserDefaults() -> AuthResult? {
        guard let authResultData = UserDefaults.standard.data(forKey: AppConstants.userDefaultsAuthResultKey),
            let authResult = try? JSONDecoder().decode(AuthResult.self, from: authResultData)
        else {
            return nil
        }

        // Сохраняем в Keychain
        do {
            try saveAuthResult(authResult)
            AppLogger.shared.info(
                "Migrated authResult from UserDefaults to Keychain", category: .keychain)
        } catch {
            AppLogger.shared.error(
                "Failed to migrate authResult", error: error, category: .keychain)
            return authResult  // Возвращаем из UserDefaults если миграция не удалась
        }

        return authResult
    }

    /// Мигрирует device token из UserDefaults в Keychain (одноразовая операция)
    private func migrateDeviceTokenFromUserDefaults() -> String? {
        guard let token = UserDefaults.standard.string(forKey: AppConstants.userDefaultsDeviceTokenKey) else {
            return nil
        }

        // Сохраняем в Keychain
        do {
            try saveDeviceToken(token)
            AppLogger.shared.info(
                "Migrated deviceToken from UserDefaults to Keychain", category: .keychain)
        } catch {
            AppLogger.shared.error(
                "Failed to migrate deviceToken", error: error, category: .keychain)
            return token  // Возвращаем из UserDefaults если миграция не удалась
        }

        return token
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveError(OSStatus)
    case deleteError(OSStatus)
    case encodingError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .saveError(let status):
            return "Ошибка сохранения в Keychain: \(status)"
        case .deleteError(let status):
            return "Ошибка удаления из Keychain: \(status)"
        case .encodingError:
            return "Ошибка кодирования данных"
        case .decodingError:
            return "Ошибка декодирования данных"
        }
    }
}
