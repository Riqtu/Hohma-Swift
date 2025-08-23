import Foundation

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Светлая"
        case .dark:
            return "Темная"
        case .system:
            return "Системная"
        }
    }
    
    var iconName: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "gear"
        }
    }
}

struct ThemeSettings {
    var currentTheme: AppTheme = .system
}
