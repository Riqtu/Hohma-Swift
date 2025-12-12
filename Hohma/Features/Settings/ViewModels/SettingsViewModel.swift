import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var themeSettings = ThemeSettings()
    @Published var raceSoundVolume: Double = 0.5 {
        didSet {
            saveRaceSoundVolume()
            // Обновляем громкость в сервисе звука
            RaceAudioService.shared.updateVolume(raceSoundVolume)
        }
    }

    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    private let raceSoundVolumeKey = "race_sound_volume"

    init() {
        loadThemeSettings()
        loadRaceSoundVolume()
        // Применяем сохраненную тему при инициализации
        applyTheme(themeSettings.currentTheme)
        // Применяем сохраненную громкость
        RaceAudioService.shared.updateVolume(raceSoundVolume)
        print(
            "🎨 SettingsViewModel: Инициализирован с темой: \(themeSettings.currentTheme.rawValue), громкость: \(raceSoundVolume)")
    }

    func setTheme(_ theme: AppTheme) {
        themeSettings.currentTheme = theme
        saveThemeSettings()
        applyTheme(theme)
    }

    func applySavedTheme() {
        // Перезагружаем настройки из UserDefaults перед применением
        loadThemeSettings()
        // Применяем сохраненную тему (например, при возвращении в приложение)
        applyTheme(themeSettings.currentTheme)
    }

    private func loadThemeSettings() {
        if let savedTheme = userDefaults.string(forKey: themeKey),
            let theme = AppTheme(rawValue: savedTheme)
        {
            themeSettings.currentTheme = theme
        } else {
            // Если тема не найдена, используем системную по умолчанию
            themeSettings.currentTheme = .system
        }
    }

    private func saveThemeSettings() {
        userDefaults.set(themeSettings.currentTheme.rawValue, forKey: themeKey)
        userDefaults.synchronize()  // Принудительно сохраняем изменения
    }
    
    private func loadRaceSoundVolume() {
        if userDefaults.object(forKey: raceSoundVolumeKey) != nil {
            raceSoundVolume = userDefaults.double(forKey: raceSoundVolumeKey)
        } else {
            // Значение по умолчанию
            raceSoundVolume = 0.5
        }
    }
    
    private func saveRaceSoundVolume() {
        userDefaults.set(raceSoundVolume, forKey: raceSoundVolumeKey)
        userDefaults.synchronize()
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .light:
            setColorScheme(.light)
        case .dark:
            setColorScheme(.dark)
        case .system:
            setColorScheme(nil)
        }

        // Убеждаемся, что изменения применились
        DispatchQueue.main.async {
            self.objectWillChange.send()
            AppLogger.shared.debug("🎨 SettingsViewModel: UI обновлен для темы: \(theme.rawValue)", category: .ui)
        }
    }

    private func setColorScheme(_ colorScheme: ColorScheme?) {
        let colorSchemeString =
            colorScheme == nil ? "system" : (colorScheme == .dark ? "dark" : "light")
        AppLogger.shared.debug("🎨 SettingsViewModel: Установка ColorScheme: \(colorSchemeString)", category: .ui)

        // Применяем тему к приложению
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                let newStyle = colorScheme?.userInterfaceStyle ?? .unspecified
                if window.overrideUserInterfaceStyle != newStyle {
                    window.overrideUserInterfaceStyle = newStyle
                }
            }
        }

        // Для macOS также применяем тему
        #if os(macOS)
            if let colorScheme = colorScheme {
                let newAppearance =
                    colorScheme == .dark
                    ? NSAppearance(named: .darkAqua)
                    : NSAppearance(named: .aqua)

                if NSApp.appearance != newAppearance {
                    NSApp.appearance = newAppearance
                }
            } else {
                if NSApp.appearance != nil {
                    NSApp.appearance = nil
                }
            }
        #endif
    }
}

extension ColorScheme {
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        @unknown default:
            return .unspecified
        }
    }
}
