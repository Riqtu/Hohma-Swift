//
//  Subscription.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Foundation

// MARK: - Subscription Model
struct Subscription: Codable, Identifiable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let followerId: String
    let followingId: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
        case followerId
        case followingId
    }
}

// MARK: - User Profile for Subscriptions
struct UserProfile: Codable, Identifiable {
    let id: String
    let name: String?
    let username: String?
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case firstName
        case lastName
        case avatarUrl
    }

    // Вычисляемое свойство для отображения имени
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        } else if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        } else if let username = username {
            return username
        } else {
            return "Пользователь"
        }
    }
}

// MARK: - Subscription Response Models
struct SubscriptionResponse: Codable {
    let result: SubscriptionResult
}

struct SubscriptionResult: Codable {
    let data: SubscriptionData
}

struct SubscriptionData: Codable {
    let json: Subscription
}

// MARK: - Boolean Response Wrapper
struct BooleanResponse: Codable {
    let value: Bool
}
