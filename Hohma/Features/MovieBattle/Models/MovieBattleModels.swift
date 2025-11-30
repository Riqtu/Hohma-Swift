import Foundation
import SwiftUI

// MARK: - Movie Battle Models

enum MovieBattleStatus: String, Codable, CaseIterable {
    case created = "CREATED"
    case collecting = "COLLECTING"
    case generating = "GENERATING"
    case voting = "VOTING"
    case finished = "FINISHED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .created: return "Создана"
        case .collecting: return "Сбор фильмов"
        case .generating: return "Генерация"
        case .voting: return "Голосование"
        case .finished: return "Завершена"
        case .cancelled: return "Отменена"
        }
    }
}

enum GenerationStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case generating = "GENERATING"
    case titleReady = "TITLE_READY"
    case posterReady = "POSTER_READY"
    case descriptionReady = "DESCRIPTION_READY"
    case completed = "COMPLETED"
    case failed = "FAILED"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидание..."
        case .generating: return "Генерация..."
        case .titleReady: return "Название готово"
        case .posterReady: return "Постер готов"
        case .descriptionReady: return "Описание готово"
        case .completed: return "Готово"
        case .failed: return "Ошибка"
        }
    }
}

struct MovieBattle: Codable, Identifiable {
    let id: String
    let name: String
    let status: MovieBattleStatus
    let isPrivate: Bool
    let minMovies: Int
    let maxMovies: Int
    let minParticipants: Int
    let votingTimeSeconds: Int?
    let currentRound: Int
    let moviesRemaining: Int
    let createdAt: String
    let updatedAt: String
    let startedAt: String?
    let finishedAt: String?
    let creator: MovieBattleCreator
    let participants: [MovieBattleParticipant]?
    let movies: [MovieCard]?
    let votes: [Vote]?
    let _count: MovieBattleCount?

    enum CodingKeys: String, CodingKey {
        case id, name, status, isPrivate, minMovies, maxMovies, minParticipants
        case votingTimeSeconds, currentRound, moviesRemaining
        case createdAt, updatedAt, startedAt, finishedAt
        case creator, participants, movies, votes
        case _count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(MovieBattleStatus.self, forKey: .status)

        if let privateInt = try? container.decode(Int.self, forKey: .isPrivate) {
            isPrivate = privateInt != 0
        } else {
            isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        }

        minMovies = try container.decode(Int.self, forKey: .minMovies)
        maxMovies = try container.decode(Int.self, forKey: .maxMovies)
        minParticipants = try container.decode(Int.self, forKey: .minParticipants)
        votingTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .votingTimeSeconds)
        currentRound = try container.decode(Int.self, forKey: .currentRound)
        moviesRemaining = try container.decode(Int.self, forKey: .moviesRemaining)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)

        if let start = try? container.decodeIfPresent(String.self, forKey: .startedAt) {
            startedAt = start == "<null>" ? nil : start
        } else {
            startedAt = nil
        }

        if let end = try? container.decodeIfPresent(String.self, forKey: .finishedAt) {
            finishedAt = end == "<null>" ? nil : end
        } else {
            finishedAt = nil
        }

        creator = try container.decode(MovieBattleCreator.self, forKey: .creator)
        participants = try container.decodeIfPresent([MovieBattleParticipant].self, forKey: .participants)
        movies = try container.decodeIfPresent([MovieCard].self, forKey: .movies)
        votes = try container.decodeIfPresent([Vote].self, forKey: .votes)
        _count = try container.decodeIfPresent(MovieBattleCount.self, forKey: ._count)
    }
    
    // Вычисляемые свойства для получения количества
    var participantCount: Int {
        if let count = _count?.participants {
            return count
        }
        return participants?.count ?? 0
    }
    
    var movieCount: Int {
        if let count = _count?.movies {
            return count
        }
        return movies?.count ?? 0
    }
}

struct MovieBattleCount: Codable {
    let participants: Int?
    let movies: Int
}

struct MovieBattleCreator: Codable {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?
}

struct MovieBattleParticipant: Codable, Identifiable {
    let id: String
    let movieBattleId: String
    let userId: String
    let joinedAt: String
    let user: MovieBattleUser

    enum CodingKeys: String, CodingKey {
        case id, movieBattleId, userId, joinedAt, user
    }
}

struct MovieBattleUser: Codable {
    let id: String
    let name: String?
    let username: String?
    let avatarUrl: String?
}

struct MovieCard: Codable, Identifiable {
    let id: String
    let movieBattleId: String
    let originalTitle: String
    let originalDescription: String?
    let originalPosterUrl: String?
    let originalKinopoiskId: String?
    let generatedTitle: String?
    let generatedPosterUrl: String?
    let generatedDescription: String?
    let generationStatus: GenerationStatus
    let generationError: String?
    let addedBy: MovieBattleUser?
    let eliminatedAtRound: Int?
    let finalPosition: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, movieBattleId, originalTitle, originalDescription
        case originalPosterUrl, originalKinopoiskId
        case generatedTitle, generatedPosterUrl, generatedDescription
        case generationStatus, generationError
        case addedBy, eliminatedAtRound, finalPosition
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        movieBattleId = try container.decode(String.self, forKey: .movieBattleId)
        originalTitle = try container.decode(String.self, forKey: .originalTitle)
        originalDescription = try container.decodeIfPresent(String.self, forKey: .originalDescription)
        originalPosterUrl = try container.decodeIfPresent(String.self, forKey: .originalPosterUrl)
        originalKinopoiskId = try container.decodeIfPresent(String.self, forKey: .originalKinopoiskId)
        generatedTitle = try container.decodeIfPresent(String.self, forKey: .generatedTitle)
        generatedPosterUrl = try container.decodeIfPresent(String.self, forKey: .generatedPosterUrl)
        generatedDescription = try container.decodeIfPresent(String.self, forKey: .generatedDescription)
        generationStatus = try container.decode(GenerationStatus.self, forKey: .generationStatus)
        generationError = try container.decodeIfPresent(String.self, forKey: .generationError)
        addedBy = try container.decodeIfPresent(MovieBattleUser.self, forKey: .addedBy)
        eliminatedAtRound = try container.decodeIfPresent(Int.self, forKey: .eliminatedAtRound)
        finalPosition = try container.decodeIfPresent(Int.self, forKey: .finalPosition)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    // Вычисляемое свойство для отображения названия
    // Показываем сгенерированное название, если оно есть, иначе скрываем оригинальное до генерации
    var displayTitle: String {
        if let generated = generatedTitle, !generated.isEmpty {
            return generated
        }
        // Если генерация еще не началась или не завершена, не показываем название
        if generationStatus == .pending || generationStatus == .generating {
            return "Генерация..."
        }
        // Если генерация завершена, но названия нет, показываем оригинальное
        return originalTitle
    }
    
    // Проверка, готово ли название для отображения
    var hasGeneratedTitle: Bool {
        if let generated = generatedTitle, !generated.isEmpty {
            return true
        }
        return generationStatus == .completed || generationStatus == .failed
    }

    // Вычисляемое свойство для отображения постера
    var displayPosterUrl: String? {
        generatedPosterUrl ?? originalPosterUrl
    }

    // Вычисляемое свойство для отображения описания
    var displayDescription: String? {
        generatedDescription ?? originalDescription
    }

    // Проверка, выбыл ли фильм
    var isEliminated: Bool {
        eliminatedAtRound != nil
    }

    // Проверка, является ли победителем
    var isWinner: Bool {
        finalPosition == 1
    }
}

struct Vote: Codable, Identifiable {
    let id: String
    let movieBattleId: String
    let roundNumber: Int
    let movieCardId: String
    let userId: String
    let createdAt: String
    let user: MovieBattleUser?
    let movieCard: MovieCard?

    enum CodingKeys: String, CodingKey {
        case id, movieBattleId, roundNumber, movieCardId, userId, createdAt
        case user, movieCard
    }
}

// MARK: - Request/Response Models

struct CreateMovieBattleRequest: Codable {
    let name: String
    let minMovies: Int
    let maxMovies: Int
    let minParticipants: Int
    let votingTimeSeconds: Int?
    let isPrivate: Bool
}

struct AddMovieRequest: Codable {
    let battleId: String
    let kinopoiskId: String?
    let title: String
    let description: String?
    let posterUrl: String?
}

struct VoteRequest: Codable {
    let battleId: String
    let movieCardId: String
}

