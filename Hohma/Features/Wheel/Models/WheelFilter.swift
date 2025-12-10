//
//  WheelFilter.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Foundation

// MARK: - Wheel Filter Types
enum WheelFilter: String, CaseIterable, Codable {
    case my = "my"
    case following = "following"
    case all = "all"

    var displayName: String {
        switch self {
        case .my:
            return "Мои"
        case .following:
            return "Подписки"
        case .all:
            return "Все"
        }
    }
}
