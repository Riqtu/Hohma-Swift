//
//  Sector.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

struct ColorJSON: Codable, Equatable {
    let h: Double
    let s: Double
    let l: Double
}

struct PatternPositionJSON: Codable, Equatable {
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

    // CodingKeys for custom decoding
    private enum CodingKeys: String, CodingKey {
        case id, label, color, name, eliminated, winner
        case description, pattern, patternPosition, poster, genre, rating, year
        case labelColor, labelHidden, wheelId, userId, user, createdAt, updatedAt
    }

    // Regular initializer for mock objects
    init(
        id: String, label: String, color: ColorJSON, name: String, eliminated: Bool, winner: Bool,
        description: String?, pattern: String?, patternPosition: PatternPositionJSON?,
        poster: String?, genre: String?, rating: String?, year: String?, labelColor: String?,
        labelHidden: Bool, wheelId: String, userId: String?, user: AuthUser?, createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.label = label
        self.color = color
        self.name = name
        self.eliminated = eliminated
        self.winner = winner
        self.description = description
        self.pattern = pattern
        self.patternPosition = patternPosition
        self.poster = poster
        self.genre = genre
        self.rating = rating
        self.year = year
        self.labelColor = labelColor
        self.labelHidden = labelHidden
        self.wheelId = wheelId
        self.userId = userId
        self.user = user
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoding to handle numeric boolean values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        color = try container.decode(ColorJSON.self, forKey: .color)
        name = try container.decode(String.self, forKey: .name)

        // Handle boolean fields that might come as numbers
        if let boolValue = try? container.decode(Bool.self, forKey: .eliminated) {
            eliminated = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .eliminated) {
            eliminated = intValue != 0
        } else {
            eliminated = false
        }

        if let boolValue = try? container.decode(Bool.self, forKey: .winner) {
            winner = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .winner) {
            winner = intValue != 0
        } else {
            winner = false
        }

        if let boolValue = try? container.decode(Bool.self, forKey: .labelHidden) {
            labelHidden = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .labelHidden) {
            labelHidden = intValue != 0
        } else {
            labelHidden = false
        }

        description = try? container.decode(String.self, forKey: .description)
        pattern = try? container.decode(String.self, forKey: .pattern)
        patternPosition = try? container.decode(PatternPositionJSON.self, forKey: .patternPosition)
        poster = try? container.decode(String.self, forKey: .poster)
        genre = try? container.decode(String.self, forKey: .genre)
        rating = try? container.decode(String.self, forKey: .rating)
        year = try? container.decode(String.self, forKey: .year)
        labelColor = try? container.decode(String.self, forKey: .labelColor)
        wheelId = try container.decode(String.self, forKey: .wheelId)
        userId = try? container.decode(String.self, forKey: .userId)
        user = try? container.decode(AuthUser.self, forKey: .user)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

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

    // Тестовый сектор с паттерном
    static let mockWithPattern = Sector(
        id: "681e3151041024f3c3a92b41",
        label: "Паттерн",
        color: ColorJSON(h: 30, s: 80, l: 50),  // Оранжевый
        name: "Сектор с паттерном",
        eliminated: false,
        winner: false,
        description: "Тестовый сектор с паттерном",
        pattern: "https://picsum.photos/400/400",  // Тестовое изображение
        patternPosition: PatternPositionJSON(x: 0, y: 0, z: 10),  // Небольшое увеличение
        poster: nil,
        genre: nil,
        rating: nil,
        year: nil,
        labelColor: "#FFD700",  // Золотой цвет для текста
        labelHidden: false,
        wheelId: "681e3146041024f3c3a92b3a",
        userId: "6804fc3fd253e514c3fb6ae0",
        user: AuthUser.mock,
        createdAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:09.886Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-05-09T16:46:49.258Z") ?? Date()
    )
}

// MARK: - Sector Extensions
extension Sector {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "label": label,
            "color": [
                "h": color.h,
                "s": color.s,
                "l": color.l,
            ],
            "name": name,
            "eliminated": eliminated,
            "winner": winner,
            "labelHidden": labelHidden,
            "wheelId": wheelId,
        ]

        // Добавляем опциональные поля только если они не nil
        if let description = description { dict["description"] = description }
        if let pattern = pattern { dict["pattern"] = pattern }
        if let patternPosition = patternPosition {
            dict["patternPosition"] = [
                "x": patternPosition.x,
                "y": patternPosition.y,
                "z": patternPosition.z,
            ]
        }
        if let poster = poster { dict["poster"] = poster }
        if let genre = genre { dict["genre"] = genre }
        if let rating = rating { dict["rating"] = rating }
        if let year = year { dict["year"] = year }
        if let labelColor = labelColor { dict["labelColor"] = labelColor }
        if let userId = userId { dict["userId"] = userId }

        return dict
    }
}

// MARK: - Equatable
extension Sector: Equatable {
    static func == (lhs: Sector, rhs: Sector) -> Bool {
        return lhs.id == rhs.id && lhs.label == rhs.label && lhs.name == rhs.name
            && lhs.eliminated == rhs.eliminated && lhs.winner == rhs.winner
            && lhs.labelHidden == rhs.labelHidden && lhs.wheelId == rhs.wheelId
            && lhs.userId == rhs.userId
    }
}

struct SectorWithRelations: Codable {
    let sector: Sector
    let wheel: Wheel
    let user: AuthUser?
    let bets: [Bet]
}
