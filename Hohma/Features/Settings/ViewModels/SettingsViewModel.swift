import SwiftUI
import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var themeSettings = ThemeSettings()
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    init() {
        loadThemeSettings()
    }
    
    func setTheme(_ theme: AppTheme) {
        themeSettings.currentTheme = theme
        saveThemeSettings()
        applyTheme(theme)
    }
    
    private func loadThemeSettings() {
        if let savedTheme = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            themeSettings.currentTheme = theme
        }
    }
    
    private func saveThemeSettings() {
        userDefaults.set(themeSettings.currentTheme.rawValue, forKey: themeKey)
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
    }
    
    private func setColorScheme(_ colorScheme: ColorScheme?) {
        // Применяем тему к приложению
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = colorScheme?.userInterfaceStyle ?? .unspecified
            }
        }
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
