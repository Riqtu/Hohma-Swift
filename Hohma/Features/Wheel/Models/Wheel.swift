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
    let createdAt: Date
    let updatedAt: Date
    
    // Relations
    let themeId: String?
    let userId: String?
}

struct WheelWithRelations: Codable {
    let id: String
    let name: String
    let status: WheelStatus?
    let createdAt: Date
    let updatedAt: Date
    let themeId: String?
    let userId: String?
    let sectors: [Sector]
    let bets: [Bet]?
    let theme: WheelTheme?
    let user: AuthUser?
}
