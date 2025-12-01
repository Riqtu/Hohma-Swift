//
//  StickerService.swift
//  Hohma
//
//  Created by Assistant on 01.12.2025.
//

import Foundation

final class StickerService: TRPCServiceProtocol {
    static let shared = StickerService()
    private init() {}
    
    // MARK: - Get All Packs
    func getAllPacks(includeInactive: Bool = false) async throws -> [StickerPack] {
        let input: [String: Any] = [
            "includeInactive": includeInactive
        ]
        return try await trpcService.executeGET(endpoint: "sticker.getAllPacks", input: input)
    }
    
    // MARK: - Get Pack Stickers
    func getPackStickers(packId: String) async throws -> [Sticker] {
        let input: [String: Any] = [
            "packId": packId
        ]
        return try await trpcService.executeGET(endpoint: "sticker.getPackStickers", input: input)
    }
}

