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

// MARK: - Параметры пагинации

struct PaginationParams: Codable {
    let page: Int
    let limit: Int
    let cursor: String?

    init(page: Int = 1, limit: Int = 20, cursor: String? = nil) {
        self.page = page
        self.limit = limit
        self.cursor = cursor
    }
}
