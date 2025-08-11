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
    let user: AuthUser?

    let createdAt: Date
    let updatedAt: Date

    static let mock = Sector(
        id: "681e3151041024f3c3a92b3b",
        label: "1",
        color: ColorJSON(h: 0, s: 80, l: 50),  // Красный
        name: "Первый сектор",
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
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )

    static let mock2 = Sector(
        id: "681e3151041024f3c3a92b3c",
        label: "2",
        color: ColorJSON(h: 120, s: 80, l: 50),  // Зеленый
        name: "Второй сектор",
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
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )

    static let mock3 = Sector(
        id: "681e3151041024f3c3a92b3d",
        label: "3",
        color: ColorJSON(h: 240, s: 80, l: 50),  // Синий
        name: "Третий сектор",
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
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )

    static let mock4 = Sector(
        id: "681e3151041024f3c3a92b3e",
        label: "4",
        color: ColorJSON(h: 60, s: 80, l: 50),  // Желтый
        name: "Четвертый сектор",
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
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )

    static let mock5 = Sector(
        id: "681e3151041024f3c3a92b3f",
        label: "5",
        color: ColorJSON(h: 300, s: 80, l: 50),  // Пурпурный
        name: "Пятый сектор",
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
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )

    static let mock6 = Sector(
        id: "681e3151041024f3c3a92b40",
        label: "6",
        color: ColorJSON(h: 180, s: 80, l: 50),  // Голубой
        name: "Шестой сектор",
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
        user: AuthUser.mock,
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
