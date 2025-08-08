//
//  Bet.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation


struct Bet: Codable, Identifiable {
    let id: String
    let amount: Int
    let createdAt: Date
    let updatedAt: Date
    let paidOut: Bool
    
    let userId: String
    let sectorId: String
    let wheelId: String
}
