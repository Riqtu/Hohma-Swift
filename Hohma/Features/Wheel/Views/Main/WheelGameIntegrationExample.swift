//
//  WheelGameIntegrationExample.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

// Пример интеграции компонента колеса фортуны в приложение
struct WheelGameIntegrationExample: View {
    @ObserveInjection var inject
    @State private var showingGame = false
    @State private var selectedWheel: WheelWithRelations?

    // Мок данные для примера
    private let mockWheel = WheelWithRelations(
        id: "example-wheel",
        name: "Колесо фильмов",
        status: .active,
        isPrivate: false,
        createdAt: Date(),
        updatedAt: Date(),
        themeId: "theme1",
        userId: "user1",
        sectors: [
            Sector.mock,
            Sector.mock,
            Sector.mock,
        ],
        bets: [],
        theme: WheelTheme.mock,
        user: AuthUser.mock
    )

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Колесо Фортуны")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Пример интеграции компонента")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Карточка колеса
                WheelCardView(cardData: mockWheel)
                    .onTapGesture {
                        selectedWheel = mockWheel
                        showingGame = true
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Пример")
            .sheet(isPresented: $showingGame) {
                if let wheel = selectedWheel {
                    FortuneWheelGameView(
                        wheelData: wheel,
                        currentUser: AuthUser.mock
                    )
                }
            }
        }
    }
}

// Пример навигации через NavigationLink
struct WheelGameNavigationExample: View {
    @ObserveInjection var inject
    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    destination: FortuneWheelGameView(
                        wheelData: WheelWithRelations(
                            id: "nav-example",
                            name: "Навигационный пример",
                            status: .active,
                            isPrivate: false,
                            createdAt: Date(),
                            updatedAt: Date(),
                            themeId: "theme1",
                            userId: "user1",
                            sectors: [Sector.mock, Sector.mock],
                            bets: [],
                            theme: WheelTheme.mock,
                            user: AuthUser.mock
                        ),
                        currentUser: AuthUser.mock
                    )
                ) {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.blue)
                        Text("Играть в колесо фортуны")
                    }
                }
            }
            .navigationTitle("Навигация")
        }
    }
}

// Пример с кастомными данными
struct CustomWheelGameExample: View {
    @ObserveInjection var inject
    @State private var customWheel: WheelWithRelations

    init() {
        // Создаем кастомное колесо
        let customSectors = [
            Sector(
                id: "sector1",
                label: "Фильм 1",
                color: ColorJSON(h: 0, s: 60, l: 30),
                name: "Название фильма 1",
                eliminated: false,
                winner: false,
                description: "Описание фильма 1",
                pattern: nil,
                patternPosition: PatternPositionJSON(x: 0, y: 0, z: 0),
                poster: nil,
                genre: "Драма",
                rating: "8.5",
                year: "2023",
                labelColor: nil,
                labelHidden: false,
                wheelId: "custom-wheel",
                userId: "user1",
                user: AuthUser.mock,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Sector(
                id: "sector2",
                label: "Фильм 2",
                color: ColorJSON(h: 120, s: 60, l: 30),
                name: "Название фильма 2",
                eliminated: false,
                winner: false,
                description: "Описание фильма 2",
                pattern: nil,
                patternPosition: PatternPositionJSON(x: 0, y: 0, z: 0),
                poster: nil,
                genre: "Комедия",
                rating: "7.8",
                year: "2022",
                labelColor: nil,
                labelHidden: false,
                wheelId: "custom-wheel",
                userId: "user1",
                user: AuthUser.mock,
                createdAt: Date(),
                updatedAt: Date()
            ),
        ]

        self._customWheel = State(
            initialValue: WheelWithRelations(
                id: "custom-wheel",
                name: "Кастомное колесо",
                status: .active,
                isPrivate: false,
                createdAt: Date(),
                updatedAt: Date(),
                themeId: "custom-theme",
                userId: "user1",
                sectors: customSectors,
                bets: [],
                theme: WheelTheme.mock,
                user: AuthUser.mock
            ))
    }

    var body: some View {
        FortuneWheelGameView(
            wheelData: customWheel,
            currentUser: AuthUser.mock
        )
    }
}

#Preview {
    WheelGameIntegrationExample()
}
