//
//  NavigationCoordinator.swift
//  Hohma
//
//  Created for navigation management
//

import Foundation

/// Координатор навигации для управления переходами между экранами
@MainActor
class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    /// Маппинг destination строк на теги табов/секций
    func mapDestination(_ destination: String) -> String {
        switch destination {
        case "wheel", "wheelList":
            return "wheelList"
        case "home":
            return "home"
        case "race":
            return "race"
        case "chat":
            return "chat"
        case "profile":
            return "profile"
        case "settings":
            return "settings"
        case "stats":
            return "stats"
        case "movieBattle":
            return "movieBattle"
        default:
            return destination
        }
    }
    
    /// Проверяет, нужно ли обрабатывать навигацию через HomeView для iPhone
    func shouldHandleViaHomeView(_ destination: String, isSidebarPreferred: Bool) -> Bool {
        guard !isSidebarPreferred else { return false }
        
        let mappedDestination = mapDestination(destination)
        return mappedDestination == "wheelList" || mappedDestination == "race"
            || mappedDestination == "stats" || mappedDestination == "movieBattle"
    }
}
