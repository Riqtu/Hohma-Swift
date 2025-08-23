import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var themeSettings = ThemeSettings()

    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"

    init() {
        loadThemeSettings()
        // Применяем сохраненную тему при инициализации
        applyTheme(themeSettings.currentTheme)
    }

    func setTheme(_ theme: AppTheme) {
        themeSettings.currentTheme = theme
        saveThemeSettings()
        applyTheme(theme)
    }

    func applySavedTheme() {
        // Применяем сохраненную тему (например, при возвращении в приложение)
        applyTheme(themeSettings.currentTheme)
    }

    private func loadThemeSettings() {
        if let savedTheme = userDefaults.string(forKey: themeKey),
            let theme = AppTheme(rawValue: savedTheme)
        {
            themeSettings.currentTheme = theme
        }
    }

    private func saveThemeSettings() {
        userDefaults.set(themeSettings.currentTheme.rawValue, forKey: themeKey)
        userDefaults.synchronize()  // Принудительно сохраняем изменения
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
        }
    }

    private func setColorScheme(_ colorScheme: ColorScheme?) {
        // Применяем тему к приложению
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = colorScheme?.userInterfaceStyle ?? .unspecified
            }
        }

        // Для macOS также применяем тему
        #if os(macOS)
            if let colorScheme = colorScheme {
                NSApp.appearance =
                    colorScheme == .dark
                    ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            } else {
                NSApp.appearance = nil
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
