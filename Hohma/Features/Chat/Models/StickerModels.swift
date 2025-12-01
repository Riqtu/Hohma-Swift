//
//  StickerModels.swift
//  Hohma
//
//  Created by Assistant on 01.12.2025.
//

import Foundation

// MARK: - Sticker Pack
struct StickerPack: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let iconUrl: String?
    let isActive: Bool
    let order: Int
    let createdAt: String
    let updatedAt: String
    let _count: StickerCount?
    
    struct StickerCount: Codable {
        let stickers: Int
    }
}

// MARK: - Sticker
struct Sticker: Codable, Identifiable {
    let id: String
    let packId: String
    let imageUrl: String
    let emoji: String?
    let isAnimated: Bool
    let order: Int
    let createdAt: String
    let updatedAt: String
}

