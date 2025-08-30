//
//  WheelList.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

struct WheelListResponse: Codable {
    let result: ResultData
}

struct ResultData: Codable {
    let data: ResultDataContent
}

struct ResultDataContent: Codable {
    let json: [WheelWithRelations]
}

// MARK: - Пагинация

struct WheelListPaginationResponse: Codable {
    let result: WheelListPaginationResult
}

struct WheelListPaginationResult: Codable {
    let data: WheelListPaginationData
}

struct WheelListPaginationData: Codable {
    let json: WheelListPaginationContent
}

struct WheelListPaginationContent: Codable {
    let data: [WheelWithRelations]
    let pagination: PaginationInfo
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let totalCount: Int
    let totalPages: Int
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    let nextCursor: String?
}

// MARK: - Удаление колеса

struct WheelDeleteResponse: Codable {
    let result: WheelDeleteResult
}

struct WheelDeleteResult: Codable {
    let data: WheelDeleteData
}

struct WheelDeleteData: Codable {
    let json: Wheel
}

// MARK: - Параметры пагинации с фильтрами

struct PaginationParams: Codable {
    let page: Int
    let limit: Int
    let cursor: String?
    let filter: WheelFilter?

    init(page: Int = 1, limit: Int = 20, cursor: String? = nil, filter: WheelFilter? = nil) {
        self.page = page
        self.limit = limit
        self.cursor = cursor
        self.filter = filter
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "page": page,
            "limit": limit,
        ]

        if let cursor = cursor {
            dict["cursor"] = cursor
        }

        if let filter = filter {
            dict["filter"] = filter.rawValue
        }

        return dict
    }
}
