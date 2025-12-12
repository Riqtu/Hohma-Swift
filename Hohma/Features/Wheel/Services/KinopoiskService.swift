//
//  KinopoiskService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation

struct KinopoiskMovie: Codable {
    let id: Int
    let name: String
    let alternativeName: String?
    let year: Int
    let genres: [KinopoiskGenre]?
    let poster: KinopoiskPoster?
    let description: String?
    let shortDescription: String?
    let rating: KinopoiskRating?
    let votes: KinopoiskVotes?
    let movieLength: Int?
    let isSeries: Int?  // API возвращает 0 или 1
    let type: String?
    let typeNumber: Int?
    let top250: TopFieldValue?  // Может быть строкой или числом
    let countries: [KinopoiskCountry]?
    let names: [KinopoiskName]?

    // Кастомный инициализатор для безопасного декодирования
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Обязательные поля
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.year = try container.decode(Int.self, forKey: .year)

        // Опциональные поля с безопасным декодированием
        self.alternativeName = try? container.decode(String.self, forKey: .alternativeName)
        self.genres = try? container.decode([KinopoiskGenre].self, forKey: .genres)
        self.poster = try? container.decode(KinopoiskPoster.self, forKey: .poster)
        self.description = try? container.decode(String.self, forKey: .description)
        self.shortDescription = try? container.decode(String.self, forKey: .shortDescription)
        self.rating = try? container.decode(KinopoiskRating.self, forKey: .rating)
        self.votes = try? container.decode(KinopoiskVotes.self, forKey: .votes)
        self.movieLength = try? container.decode(Int.self, forKey: .movieLength)
        self.isSeries = try? container.decode(Int.self, forKey: .isSeries)
        self.type = try? container.decode(String.self, forKey: .type)
        self.typeNumber = try? container.decode(Int.self, forKey: .typeNumber)
        self.top250 = try? container.decode(TopFieldValue.self, forKey: .top250)
        self.countries = try? container.decode([KinopoiskCountry].self, forKey: .countries)
        self.names = try? container.decode([KinopoiskName].self, forKey: .names)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, alternativeName, year, genres, poster, description
        case shortDescription, rating, votes, movieLength, isSeries, type
        case typeNumber, top250, countries, names
    }
}

// Для обработки полей, которые могут быть как строкой, так и числом, или null
enum TopFieldValue: Codable {
    case string(String)
    case int(Int)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let stringValue = try? container.decode(String.self) {
            if stringValue == "<null>" || stringValue.isEmpty {
                self = .null
            } else {
                self = .string(stringValue)
            }
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct KinopoiskGenre: Codable {
    let name: String
}

struct KinopoiskCountry: Codable {
    let name: String
}

struct KinopoiskName: Codable {
    let name: String?
    let language: String?
    let type: String?
}

struct KinopoiskPoster: Codable {
    let url: String?
    let previewUrl: String?

    // Приоритет: сначала url, потом previewUrl
    var bestUrl: String? {
        return url ?? previewUrl
    }
}

struct KinopoiskRating: Codable {
    let kp: String?
    let imdb: String?
    let filmCritics: String?
    let russianFilmCritics: RatingValue?
    let await: String?

    // Кастомный декодер для обработки <null> значений
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.kp = try? container.decode(String.self, forKey: .kp)
        self.imdb = try? container.decode(String.self, forKey: .imdb)
        self.filmCritics = try? container.decode(String.self, forKey: .filmCritics)
        self.await = try? container.decode(String.self, forKey: .await)

        // Обработка russianFilmCritics которое может быть Int или String
        if let intValue = try? container.decode(Int.self, forKey: .russianFilmCritics) {
            self.russianFilmCritics = .int(intValue)
        } else if let stringValue = try? container.decode(String.self, forKey: .russianFilmCritics),
            stringValue != "<null>" && !stringValue.isEmpty
        {
            if let intFromString = Int(stringValue) {
                self.russianFilmCritics = .int(intFromString)
            } else {
                self.russianFilmCritics = nil
            }
        } else {
            self.russianFilmCritics = nil
        }
    }
}

enum RatingValue: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                RatingValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

struct KinopoiskVotes: Codable {
    let kp: Int?
    let imdb: Int?
    let filmCritics: Int?
    let russianFilmCritics: Int?
    let await: Int?
}

struct KinopoiskResponse: Codable {
    let docs: [KinopoiskMovie]
    let total: Int
    let limit: Int
    let page: Int
    let pages: Int
}

class KinopoiskService: ObservableObject {
    @MainActor
    private let networkManager = NetworkManager.shared

    // Добавляем кэш для результатов поиска
    private var searchCache: [String: [KinopoiskMovie]] = [:]
    private let cacheQueue = DispatchQueue(label: "kinopoisk.cache", qos: .userInitiated)

    // Получаем API ключ из конфигурации
    private var apiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "KINOPOISK_API_KEY") as? String ?? ""
    }

    @MainActor
    func searchMovies(query: String) async throws -> [KinopoiskMovie] {
        // Проверяем кэш сначала
        if let cachedResults = getCachedResults(for: query) {
            return cachedResults
        }

        guard let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
            let url = URL(string: "\(apiURL)/kinopoisk.getMovie")
        else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        // Для tRPC query процедур используем GET запрос с параметрами в URL
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        // tRPC ожидает параметры в формате: ?input={"json":{"query":"..."}}
        let inputData = ["json": ["query": query]]
        let inputJSONData = try JSONSerialization.data(withJSONObject: inputData)
        let inputString = String(data: inputJSONData, encoding: .utf8)!
        urlComponents.queryItems = [URLQueryItem(name: "input", value: inputString)]

        guard let finalURL = urlComponents.url else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"

        // Добавляем таймаут для предотвращения долгих запросов
        request.timeoutInterval = 10.0

        addAuthorizationHeader(to: &request)

        let response: KinopoiskResponse = try await networkManager.request(request)

        // Кэшируем результаты
        cacheResults(response.docs, for: query)

        return response.docs
    }

    // MARK: - Private Methods

    private func addAuthorizationHeader(to request: inout URLRequest) {
        // Получаем токен из Keychain
        if let token = KeychainService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Caching Methods

    private func getCachedResults(for query: String) -> [KinopoiskMovie]? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return cacheQueue.sync {
            return searchCache[normalizedQuery]
        }
    }

    private func cacheResults(_ results: [KinopoiskMovie], for query: String) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        cacheQueue.async {
            // Ограничиваем размер кэша
            if self.searchCache.count > 50 {
                // Удаляем старые записи
                let sortedKeys = self.searchCache.keys.sorted()
                let keysToRemove = sortedKeys.prefix(10)
                for key in keysToRemove {
                    self.searchCache.removeValue(forKey: key)
                }
            }
            self.searchCache[normalizedQuery] = results
        }
    }

    // Метод для очистки кэша
    func clearCache() {
        cacheQueue.async {
            self.searchCache.removeAll()
        }
    }
}
