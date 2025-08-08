//
//  Sector.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation


struct ColorJSON: Codable {
    let h: Double
    let s: Double
    let l: Double
}

struct PatternPositionJSON: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct Sector: Codable, Identifiable {
    let id: String
    let label: String
    let color: ColorJSON
    let name: String
    let eliminated: Bool
    let winner: Bool
    
    let description: String?
    let pattern: String?
    let patternPosition: PatternPositionJSON? 
    let poster: String?
    let genre: String?
    let rating: String?
    let year: String?
    let labelColor: String?
    let labelHidden: Bool
    
    let wheelId: String
    let userId: String?
    
    let createdAt: Date
    let updatedAt: Date

    static let mock = Sector(
    id: "681e3151041024f3c3a92b3b",
    label: "123",
    color: ColorJSON(h: 311, s: 60, l: 30),
    name: "Artem",
    eliminated: false,
    winner: false,
    description: nil,
    pattern: nil,
    patternPosition: PatternPositionJSON(x: 0, y: 0, z: 0),
    poster: nil,
    genre: nil,
    rating: nil,
    year: nil,
    labelColor: nil,
    labelHidden: false,
    wheelId: "681e3146041024f3c3a92b3a",
    userId: "6804fc3fd253e514c3fb6ae0",
    createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
    updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
)
}

struct SectorWithRelations: Codable {
    let sector: Sector
    let wheel: Wheel
    let user: AuthUser?
    let bets: [Bet]
}
