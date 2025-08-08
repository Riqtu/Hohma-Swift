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

