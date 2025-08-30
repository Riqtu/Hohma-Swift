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
        case id = "_id"
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
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case username
        case avatarUrl
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

// MARK: - Following/Followers Response Models
struct UserListResponse: Codable {
    let result: UserListResult
}

struct UserListResult: Codable {
    let data: UserListData
}

struct UserListData: Codable {
    let json: [UserProfile]
}

// MARK: - Is Following Response
struct IsFollowingResponse: Codable {
    let result: IsFollowingResult
}

struct IsFollowingResult: Codable {
    let data: IsFollowingData
}

struct IsFollowingData: Codable {
    let json: Bool
}
