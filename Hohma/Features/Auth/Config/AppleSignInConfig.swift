//
//  AppleSignInConfig.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Foundation

struct AppleSignInConfig {
    // Apple Developer Team ID
    static let teamId = "4D7KVU7P88"

    // Bundle ID вашего приложения
    static let bundleId = "riqtu.Hohma"

    // Apple Services ID (если используется)
    static let servicesId = "riqtu.Hohma.services"

    // Client ID для Apple Sign In
    static let clientId = bundleId

    // Redirect URI (если используется)
    static let redirectUri = "https://riqtu.ru/auth/apple/callback"
}
