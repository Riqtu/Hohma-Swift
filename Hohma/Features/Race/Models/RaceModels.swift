import Foundation
import SwiftUI

// MARK: - Road Models
struct Road: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let theme: String
    let length: Int
    let difficulty: RoadDifficulty
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    let cells: [RoadCell]?
    let raceCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, description, theme, length, difficulty, isActive
        case createdAt, updatedAt, cells
        case raceCount = "_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Handle description which might come as "<null>" string
        if let desc = try? container.decodeIfPresent(String.self, forKey: .description) {
            description = desc == "<null>" ? nil : desc
        } else {
            description = nil
        }
        theme = try container.decode(String.self, forKey: .theme)
        length = try container.decode(Int.self, forKey: .length)
        difficulty = try container.decode(RoadDifficulty.self, forKey: .difficulty)
        // Handle isActive which might come as integer (0/1)
        if let activeInt = try? container.decode(Int.self, forKey: .isActive) {
            isActive = activeInt != 0
        } else {
            isActive = try container.decode(Bool.self, forKey: .isActive)
        }
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        cells = try container.decodeIfPresent([RoadCell].self, forKey: .cells)

        // Handle _count as either Int or dictionary
        if let countInt = try? container.decode(Int.self, forKey: .raceCount) {
            raceCount = countInt
        } else if let countDict = try? container.decode([String: Int].self, forKey: .raceCount) {
            raceCount = countDict["races"]
        } else {
            raceCount = nil
        }
    }

    init(
        id: String, name: String, description: String?, theme: String, length: Int,
        difficulty: RoadDifficulty, isActive: Bool, createdAt: String, updatedAt: String,
        cells: [RoadCell]?, raceCount: Int?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.theme = theme
        self.length = length
        self.difficulty = difficulty
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cells = cells
        self.raceCount = raceCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Road, rhs: Road) -> Bool {
        lhs.id == rhs.id
    }
}

struct RoadCell: Codable, Identifiable {
    let id: String
    let roadId: String
    let position: Int
    let cellType: CellType
    let effect: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, position, effect, createdAt
        case roadId = "roadId"
        case cellType = "cellType"
    }
}

enum RoadDifficulty: String, Codable, CaseIterable {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
    case extreme = "EXTREME"

    var displayName: String {
        switch self {
        case .easy: return "Легкая"
        case .medium: return "Средняя"
        case .hard: return "Сложная"
        case .extreme: return "Экстремальная"
        }
    }
}

enum CellType: String, Codable, CaseIterable {
    case normal = "NORMAL"
    case boost = "BOOST"
    case obstacle = "OBSTACLE"
    case bonus = "BONUS"
    case finish = "FINISH"

    var displayName: String {
        switch self {
        case .normal: return "Обычная"
        case .boost: return "Ускорение"
        case .obstacle: return "Препятствие"
        case .bonus: return "Бонус"
        case .finish: return "Финиш"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .normal: return .gray
        case .boost: return .green
        case .obstacle: return .red
        case .bonus: return .blue
        case .finish: return .yellow
        }
    }
}

// MARK: - Race Models
struct Race: Codable, Identifiable {
    let id: String
    let name: String
    let status: RaceStatus
    let isPrivate: Bool
    let theme: String
    let maxPlayers: Int
    let entryFee: Int
    let prizePool: Int
    let startTime: String?
    let endTime: String?
    let createdAt: String
    let updatedAt: String
    let road: Road
    let creator: RaceCreator
    let participants: [RaceParticipant]?
    let participantCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, status, isPrivate, theme, maxPlayers, entryFee, prizePool
        case startTime, endTime, createdAt, updatedAt, road, creator, participants
        case participantCount = "_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(RaceStatus.self, forKey: .status)
        // Handle isPrivate which might come as integer (0/1)
        if let privateInt = try? container.decode(Int.self, forKey: .isPrivate) {
            isPrivate = privateInt != 0
        } else {
            isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        }
        theme = try container.decode(String.self, forKey: .theme)
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        entryFee = try container.decode(Int.self, forKey: .entryFee)
        prizePool = try container.decode(Int.self, forKey: .prizePool)
        // Handle startTime which might come as "<null>" string
        if let start = try? container.decodeIfPresent(String.self, forKey: .startTime) {
            startTime = start == "<null>" ? nil : start
        } else {
            startTime = nil
        }

        // Handle endTime which might come as "<null>" string
        if let end = try? container.decodeIfPresent(String.self, forKey: .endTime) {
            endTime = end == "<null>" ? nil : end
        } else {
            endTime = nil
        }
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        road = try container.decode(Road.self, forKey: .road)
        creator = try container.decode(RaceCreator.self, forKey: .creator)
        participants = try container.decodeIfPresent([RaceParticipant].self, forKey: .participants)

        // Handle _count as either Int or dictionary
        if let countInt = try? container.decode(Int.self, forKey: .participantCount) {
            participantCount = countInt
        } else if let countDict = try? container.decode(
            [String: Int].self, forKey: .participantCount)
        {
            participantCount = countDict["participants"]
        } else {
            participantCount = nil
        }
    }

    init(
        id: String, name: String, status: RaceStatus, isPrivate: Bool, theme: String,
        maxPlayers: Int, entryFee: Int, prizePool: Int, startTime: String?, endTime: String?,
        createdAt: String, updatedAt: String, road: Road, creator: RaceCreator,
        participants: [RaceParticipant]?, participantCount: Int?
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.isPrivate = isPrivate
        self.theme = theme
        self.maxPlayers = maxPlayers
        self.entryFee = entryFee
        self.prizePool = prizePool
        self.startTime = startTime
        self.endTime = endTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.road = road
        self.creator = creator
        self.participants = participants
        self.participantCount = participantCount
    }
}

struct RaceCreator: Codable {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // Handle name which might come as "<null>" string
        if let nameValue = try? container.decodeIfPresent(String.self, forKey: .name) {
            name = nameValue == "<null>" ? nil : nameValue
        } else {
            name = nil
        }

        // Handle username which might come as "<null>" string
        if let usernameValue = try? container.decodeIfPresent(String.self, forKey: .username) {
            username = usernameValue == "<null>" ? nil : usernameValue
        } else {
            username = nil
        }

        // Handle avatarUrl which might come as "<null>" string
        if let avatarValue = try? container.decodeIfPresent(String.self, forKey: .avatarUrl) {
            avatarUrl = avatarValue == "<null>" ? nil : avatarValue
        } else {
            avatarUrl = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, username, avatarUrl
    }
}

struct RaceParticipant: Codable, Identifiable {
    let id: String
    let raceId: String
    let userId: String
    let currentPosition: Int
    let totalMoves: Int
    let boostUsed: Int
    let obstaclesHit: Int
    let finalPosition: Int?
    let prize: Int?
    let isFinished: Bool
    let joinedAt: String
    let finishedAt: String?
    let user: RaceUser

    enum CodingKeys: String, CodingKey {
        case id, currentPosition, totalMoves, boostUsed, obstaclesHit
        case finalPosition, prize, isFinished, joinedAt, finishedAt, user
        case raceId = "raceId"
        case userId = "userId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        raceId = try container.decode(String.self, forKey: .raceId)
        userId = try container.decode(String.self, forKey: .userId)

        // Handle numeric fields that might come as different types
        // Handle currentPosition which might come as Int or String
        if let currentPositionInt = try? container.decode(Int.self, forKey: .currentPosition) {
            currentPosition = currentPositionInt
        } else if let currentPositionString = try? container.decode(
            String.self, forKey: .currentPosition)
        {
            currentPosition = Int(currentPositionString) ?? 0
        } else {
            currentPosition = 0
        }

        // Handle totalMoves which might come as Int or String
        if let totalMovesInt = try? container.decode(Int.self, forKey: .totalMoves) {
            totalMoves = totalMovesInt
        } else if let totalMovesString = try? container.decode(String.self, forKey: .totalMoves) {
            totalMoves = Int(totalMovesString) ?? 0
        } else {
            totalMoves = 0
        }

        // Handle boostUsed which might come as Int or String
        if let boostUsedInt = try? container.decode(Int.self, forKey: .boostUsed) {
            boostUsed = boostUsedInt
        } else if let boostUsedString = try? container.decode(String.self, forKey: .boostUsed) {
            boostUsed = Int(boostUsedString) ?? 0
        } else {
            boostUsed = 0
        }

        // Handle obstaclesHit which might come as Int or String
        if let obstaclesHitInt = try? container.decode(Int.self, forKey: .obstaclesHit) {
            obstaclesHit = obstaclesHitInt
        } else if let obstaclesHitString = try? container.decode(String.self, forKey: .obstaclesHit)
        {
            obstaclesHit = Int(obstaclesHitString) ?? 0
        } else {
            obstaclesHit = 0
        }

        // Handle isFinished which might come as integer (0/1)
        if let finishedInt = try? container.decode(Int.self, forKey: .isFinished) {
            isFinished = finishedInt != 0
        } else {
            isFinished = try container.decode(Bool.self, forKey: .isFinished)
        }

        joinedAt = try container.decode(String.self, forKey: .joinedAt)

        // Handle finalPosition which might come as null, "<null>" string, or integer
        if let finalPos = try? container.decodeIfPresent(Int.self, forKey: .finalPosition) {
            finalPosition = finalPos
        } else if let finalPosString = try? container.decodeIfPresent(
            String.self, forKey: .finalPosition)
        {
            finalPosition = finalPosString == "<null>" ? nil : Int(finalPosString)
        } else {
            finalPosition = nil
        }

        // Handle prize which might come as null, "<null>" string, or integer
        if let prizeValue = try? container.decodeIfPresent(Int.self, forKey: .prize) {
            prize = prizeValue
        } else if let prizeString = try? container.decodeIfPresent(String.self, forKey: .prize) {
            prize = prizeString == "<null>" ? nil : Int(prizeString)
        } else {
            prize = nil
        }

        // Handle finishedAt which might come as null, "<null>" string, or actual string
        let finishedAtValue = try container.decodeIfPresent(String.self, forKey: .finishedAt)
        finishedAt = finishedAtValue == "<null>" ? nil : finishedAtValue

        user = try container.decode(RaceUser.self, forKey: .user)
    }
}

struct RaceUser: Codable {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // Handle name which might come as "<null>" string
        if let nameValue = try? container.decodeIfPresent(String.self, forKey: .name) {
            name = nameValue == "<null>" ? nil : nameValue
        } else {
            name = nil
        }

        // Handle username which might come as "<null>" string
        if let usernameValue = try? container.decodeIfPresent(String.self, forKey: .username) {
            username = usernameValue == "<null>" ? nil : usernameValue
        } else {
            username = nil
        }

        // Handle avatarUrl which might come as "<null>" string
        if let avatarValue = try? container.decodeIfPresent(String.self, forKey: .avatarUrl) {
            avatarUrl = avatarValue == "<null>" ? nil : avatarValue
        } else {
            avatarUrl = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, username, avatarUrl
    }
}

enum RaceStatus: String, Codable, CaseIterable {
    case created = "CREATED"
    case waiting = "WAITING"
    case running = "RUNNING"
    case finished = "FINISHED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .created: return "Создана"
        case .waiting: return "Ожидает"
        case .running: return "Идет"
        case .finished: return "Завершена"
        case .cancelled: return "Отменена"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .created: return .blue
        case .waiting: return .yellow
        case .running: return .green
        case .finished: return .gray
        case .cancelled: return .red
        }
    }
}

// MARK: - Race Position Models
struct RacePosition: Codable, Identifiable {
    let id: String
    let raceId: String
    let participantId: String
    let cellId: String
    let position: Int
    let moveNumber: Int
    let diceRoll: Int?
    let moveType: MoveType
    let bonusPoints: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, position, moveNumber, bonusPoints, createdAt
        case raceId = "raceId"
        case participantId = "participantId"
        case cellId = "cellId"
        case diceRoll = "diceRoll"
        case moveType = "moveType"
    }
}

enum MoveType: String, Codable, CaseIterable {
    case normal = "NORMAL"
    case boost = "BOOST"
    case obstacle = "OBSTACLE"
    case bonus = "BONUS"

    var displayName: String {
        switch self {
        case .normal: return "Обычный"
        case .boost: return "Ускорение"
        case .obstacle: return "Препятствие"
        case .bonus: return "Бонус"
        }
    }
}

// MARK: - API Response Models
struct RaceListResponse: Codable {
    let races: [Race]
    let total: Int
    let page: Int
    let limit: Int
}

struct RoadListResponse: Codable {
    let roads: [Road]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Create Race Request
struct CreateRaceRequest: Codable {
    let name: String
    let roadId: String
    let maxPlayers: Int
    let entryFee: Int
    let isPrivate: Bool
    let theme: String
}

// MARK: - Join Race Request
struct JoinRaceRequest: Codable {
    let raceId: String
}

// MARK: - Make Move Request
struct MakeMoveRequest: Codable {
    let raceId: String
    let diceRoll: Int
}

// MARK: - Race Stats
struct RaceStats: Codable {
    let user: UserRaceStats?
    let recentRaces: [Race]
}

struct UserRaceStats: Codable {
    let racesWon: Int
    let racesPlayed: Int
    let totalPrizeMoney: Int
}

// MARK: - Simple Response Models
struct SuccessResponse: Codable {
    let success: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Handle both boolean and integer (0/1) success values
        if let successBool = try? container.decode(Bool.self) {
            success = successBool
        } else if let successInt = try? container.decode(Int.self) {
            success = successInt != 0
        } else {
            success = false
        }
    }
}
