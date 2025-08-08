import Foundation

// MARK: - Пример тестовых данных для WheelWithRelations

extension WheelWithRelations {
    static var test: WheelWithRelations {
        WheelWithRelations(
            id: "6847097426a12d6fd5c0292b",
            name: "Хохма Колесо 09 июня 2025",
            status: .created,
            createdAt: ISO8601DateFormatter().date(from: "2025-06-09T16:19:00.078Z") ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: "2025-06-09T16:19:00.078Z") ?? Date(),
            themeId: "67fa906964f9f864dc8e0590",
            userId: "6804fc3fd253e514c3fb6ae0",
            sectors: [.mock],
            bets: [],
            theme: .mock,
            user: .mock
        )
    }
}
