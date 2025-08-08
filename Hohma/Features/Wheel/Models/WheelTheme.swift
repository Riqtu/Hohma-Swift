//
//  WheelTheme.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation


struct WheelTheme: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let accentColor: String
    let mainColor: String
    let mainColorOpacity: String?
    let backgroundImageURL: String
    let backgroundVideoURL: String
    let font: String
    let createdAt: Date
    let updatedAt: Date
    
    static let mock = WheelTheme(
        id: "67fa906964f9f864dc8e0590",
        title: "Феи",
        description: "Красивая сказочная тема",
        accentColor: "#ffffff",
        mainColor: "color-mix(in oklab, #b14eaf 30%, transparent)",
        mainColorOpacity: "",
        backgroundImageURL: "https://3dd1ce17-95e244c1-f1a5-44f6-8d14-5c48edf6539c.s3.twcstorage.ru/wheelTheme/images/%D1%84%D0%B5%D1%8F.png",
        backgroundVideoURL: "https://3dd1ce17-95e244c1-f1a5-44f6-8d14-5c48edf6539c.s3.twcstorage.ru/wheelTheme/video/Gen%203%20Alpha%20Turbo%20Fairy.mp4",
        font: "oswald",
        createdAt: ISO8601DateFormatter().date(from: "2025-04-12T16:10:17.947Z") ?? Date(),
        updatedAt: ISO8601DateFormatter().date(from: "2025-04-12T16:24:35.034Z") ?? Date()
    )
}
