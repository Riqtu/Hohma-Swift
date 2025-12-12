//
//  RaceTheme.swift
//  Hohma
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

enum RaceTheme: String, CaseIterable, Identifiable {
    case `default` = "default"
    case halloween = "halloween"
    case land = "land"
    case winter = "winter"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Обычная"
        case .halloween:
            return "Хэллоуин"
        case .land:
            return "Горы"
        case .winter:
            return "Зима"
        }

    }

    var iconName: String {
        switch self {
        case .default:
            return "road.lanes"
        case .halloween:
            return "moon.stars"
        case .land:
            return "mountain"
        case .winter:
            return "snow"
        }
    }

    var sceneRaceImageName: String {
        switch self {
        case .default:
            return "SceneRace"
        case .halloween:
            return "halloweenRace"
        case .land:
            return "landRace"
        case .winter:
            return "winterRace"
        }
    }

    var sceneBackgroundImageName: String {
        switch self {
        case .default:
            return "SceneBackground"
        case .halloween:
            return "halloweenBackground"
        case .land:
            return "landBackground"
        case .winter:
            return "winterBackground"
        }
    }

    var accentColor: Color {
        switch self {
        case .default:
            return Color("AccentColor")
        case .halloween:
            return Color.orange
        case .land:
            return Color.green
        case .winter:
            return Color.blue
        }
    }
    
    var backgroundMusicFileName: (String, String) {
        switch self {
        case .default:
            return ("default", "mp3")
        case .halloween:
            return ("halloween", "mp3")
        case .land:
            return ("mountain", "wav")
        case .winter:
            return ("winter", "mp3")
        }
    }
}

// MARK: - Race Theme Manager
@MainActor
class RaceThemeManager: ObservableObject {
    @Published var currentTheme: RaceTheme = .default

    func setThemeFromRace(_ raceTheme: String?) {
        AppLogger.shared.debug("🎨 RaceThemeManager: Setting theme from race theme: '\(raceTheme ?? "nil")'", category: .general)

        guard let themeString = raceTheme else {
            AppLogger.shared.debug("🎨 RaceThemeManager: No theme string provided, using default", category: .general)
            DispatchQueue.main.async {
                self.currentTheme = .default
            }
            return
        }

        // Попробуем найти точное совпадение
        if let theme = RaceTheme(rawValue: themeString) {
            AppLogger.shared.debug("🎨 RaceThemeManager: Found exact matching theme: \(theme.rawValue)", category: .general)
            DispatchQueue.main.async {
                self.currentTheme = theme
            }
            return
        }

        // Попробуем найти совпадение без учета регистра
        let lowercasedTheme = themeString.lowercased()
        if let theme = RaceTheme.allCases.first(where: {
            $0.rawValue.lowercased() == lowercasedTheme
        }) {
            AppLogger.shared.debug("🎨 RaceThemeManager: Found case-insensitive matching theme: \(theme.rawValue)", category: .general)
            DispatchQueue.main.async {
                self.currentTheme = theme
            }
            return
        }

        // Проверим специальные случаи
        if lowercasedTheme.contains("halloween") || lowercasedTheme.contains("хэллоуин") {
            AppLogger.shared.debug("🎨 RaceThemeManager: Detected halloween theme from content", category: .general)
            DispatchQueue.main.async {
                self.currentTheme = .halloween
            }
            return
        }

        AppLogger.shared.debug("🎨 RaceThemeManager: No matching theme found for '\(themeString)', using default", category: .general)
        DispatchQueue.main.async {
            self.currentTheme = .default
        }
    }
}
