//
//  WheelStatus.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//


enum WheelStatus: String, Codable {
    case created = "CREATED"
    case active = "ACTIVE"
    case inactive = "INACTIVE"
    case completed = "COMPLETED"
}