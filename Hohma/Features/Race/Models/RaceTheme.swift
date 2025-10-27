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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Обычная"
        case .halloween:
            return "Хэллоуин"
        case .land:
            return "Горы"
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
        }
    }
}

// MARK: - Race Theme Manager
@MainActor
class RaceThemeManager: ObservableObject {
    @Published var currentTheme: RaceTheme = .default

    func setThemeFromRace(_ raceTheme: String?) {
        print("🎨 RaceThemeManager: Setting theme from race theme: '\(raceTheme ?? "nil")'")

        guard let themeString = raceTheme else {
            print("🎨 RaceThemeManager: No theme string provided, using default")
            DispatchQueue.main.async {
                self.currentTheme = .default
            }
            return
        }

        // Попробуем найти точное совпадение
        if let theme = RaceTheme(rawValue: themeString) {
            print("🎨 RaceThemeManager: Found exact matching theme: \(theme.rawValue)")
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
            print("🎨 RaceThemeManager: Found case-insensitive matching theme: \(theme.rawValue)")
            DispatchQueue.main.async {
                self.currentTheme = theme
            }
            return
        }

        // Проверим специальные случаи
        if lowercasedTheme.contains("halloween") || lowercasedTheme.contains("хэллоуин") {
            print("🎨 RaceThemeManager: Detected halloween theme from content")
            DispatchQueue.main.async {
                self.currentTheme = .halloween
            }
            return
        }

        print("🎨 RaceThemeManager: No matching theme found for '\(themeString)', using default")
        DispatchQueue.main.async {
            self.currentTheme = .default
        }
    }
}
