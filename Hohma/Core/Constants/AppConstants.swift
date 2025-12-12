//
//  AppConstants.swift
//  Hohma
//
//  Created by Assistant on 27.01.2025.
//

import Foundation

/// Централизованные константы приложения
enum AppConstants {

    // MARK: - Network Timeouts

    /// Таймаут для сетевых запросов (секунды)
    static let networkRequestTimeout: TimeInterval = 30.0

    /// Таймаут для сетевых ресурсов (секунды)
    static let networkResourceTimeout: TimeInterval = 60.0

    // MARK: - Timer Intervals

    /// Интервал обновления записи (секунды)
    static let recordingUpdateInterval: TimeInterval = 0.1

    /// Интервал обновления рейтинга (секунды)
    static let ratingUpdateInterval: TimeInterval = 0.3

    /// Интервал остановки индикатора печати (секунды)
    static let typingIndicatorTimeout: TimeInterval = 3.0

    /// Интервал debounce для поиска (секунды)
    static let searchDebounceInterval: TimeInterval = 0.5

    /// Интервал heartbeat для WebSocket (секунды)
    static let heartbeatInterval: TimeInterval = 25.0

    /// Таймаут соединения WebSocket (секунды)
    static let connectionTimeout: TimeInterval = 60.0

    /// Минимальный интервал переподключения (секунды)
    static let minReconnectInterval: TimeInterval = 2.0

    /// Максимальная задержка переподключения (секунды)
    static let maxReconnectDelay: TimeInterval = 30.0

    /// Интервал проверки соединения (секунды)
    static let connectionCheckInterval: TimeInterval = 5.0

    /// Интервал обновления колеса (секунды)
    static let wheelUpdateInterval: TimeInterval = 30.0

    /// Интервал обновления состояния колеса (секунды)
    static let wheelStateUpdateInterval: TimeInterval = 60.0

    // MARK: - UserDefaults Keys

    /// Ключ для хранения результата авторизации
    static let userDefaultsAuthResultKey = "authResult"

    /// Ключ для хранения токена устройства
    static let userDefaultsDeviceTokenKey = "deviceToken"

    /// Ключ для хранения громкости звука скачки
    static let userDefaultsRaceSoundVolumeKey = "race_sound_volume"

    // MARK: - Animation Durations

    /// Длительность анимации по умолчанию (секунды)
    static let defaultAnimationDuration: TimeInterval = 0.3

    /// Длительность быстрой анимации (секунды)
    static let fastAnimationDuration: TimeInterval = 0.1

    // MARK: - Wheel Constants

    /// Количество дополнительных оборотов колеса
    static let wheelExtraSpins: Double = 360.0 * 3

    // MARK: - Reconnection

    /// Максимальное количество попыток переподключения
    static let maxReconnectAttempts = 10
}
