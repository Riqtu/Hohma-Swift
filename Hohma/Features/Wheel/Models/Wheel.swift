//
//  Wheel.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

struct Wheel: Codable, Identifiable {
    let id: String
    let name: String
    let status: WheelStatus?
    let isPrivate: Bool
    let createdAt: Date
    let updatedAt: Date

    // Relations
    let themeId: String?
    let userId: String?
}

struct WheelWithRelations: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: WheelStatus?
    let isPrivate: Bool
    let createdAt: Date
    let updatedAt: Date
    let themeId: String?
    let userId: String?
    let sectors: [Sector]
    let bets: [Bet]?
    let theme: WheelTheme?
    let user: AuthUser?

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WheelWithRelations, rhs: WheelWithRelations) -> Bool {
        return lhs.id == rhs.id
    }
}
