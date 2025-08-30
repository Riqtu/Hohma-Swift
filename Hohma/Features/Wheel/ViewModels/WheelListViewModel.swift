//
//  WheelListViewModel.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Foundation
import SwiftUI

@MainActor
class WheelListViewModel: ObservableObject {
    @Published var wheels: [WheelWithRelations] = []
    @Published var myWheels: [WheelWithRelations] = []
    @Published var followingWheels: [WheelWithRelations] = []
    @Published var allWheels: [WheelWithRelations] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String?

    // Состояние пагинации для каждой секции
    @Published var allWheelsHasMore = true
    @Published var myWheelsHasMore = true
    @Published var followingWheelsHasMore = true

    // Отдельные состояния загрузки для каждой секции
    @Published var allWheelsLoadingMore = false
    @Published var myWheelsLoadingMore = false
    @Published var followingWheelsLoadingMore = false

    // Текущие страницы для каждой секции
    private var allWheelsPage = 1
    private var myWheelsPage = 1
    private var followingWheelsPage = 1

    let user: AuthResult?

    // Параметры пагинации
    private let pageSize = 7

    init(user: AuthResult?) {
        self.user = user
        // Инициализируем пустые списки
        self.myWheels = []
        self.followingWheels = []
        self.allWheels = []
    }

    func loadWheels() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем все три типа колес параллельно
            async let myWheelsResponse = fetchWheelsWithPagination(page: 1, filter: .my)
            async let followingWheelsResponse = fetchWheelsWithPagination(
                page: 1, filter: .following)
            async let allWheelsResponse = fetchWheelsWithPagination(page: 1, filter: .all)

            let (myWheels, followingWheels, allWheels) = try await (
                myWheelsResponse, followingWheelsResponse, allWheelsResponse
            )

            // Обновляем списки с анимацией
            withAnimation(.easeInOut(duration: 0.3)) {
                self.myWheels = myWheels.data
                self.followingWheels = followingWheels.data
                self.allWheels = allWheels.data
            }

        } catch is CancellationError {
            // Загрузка отменена
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshWheels() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Сбрасываем страницы
        allWheelsPage = 1
        myWheelsPage = 1
        followingWheelsPage = 1

        await loadWheels()
    }

    // MARK: - Пагинация для каждой секции

    func loadMoreAllWheels() async {
        guard allWheelsHasMore && !allWheelsLoadingMore else { return }

        allWheelsLoadingMore = true
        defer { allWheelsLoadingMore = false }

        allWheelsPage += 1

        do {
            let response = try await fetchWheelsWithPagination(page: allWheelsPage, filter: .all)

            if response.data.isEmpty {
                allWheelsHasMore = false
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.allWheels.append(contentsOf: response.data)
                }
            }
        } catch {
            allWheelsPage -= 1  // Откатываем страницу при ошибке
            self.error = error.localizedDescription
        }
    }

    func loadMoreMyWheels() async {
        guard myWheelsHasMore && !myWheelsLoadingMore else { return }

        myWheelsLoadingMore = true
        defer { myWheelsLoadingMore = false }

        myWheelsPage += 1

        do {
            let response = try await fetchWheelsWithPagination(page: myWheelsPage, filter: .my)

            if response.data.isEmpty {
                myWheelsHasMore = false
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.myWheels.append(contentsOf: response.data)
                }
            }
        } catch {
            myWheelsPage -= 1  // Откатываем страницу при ошибке
            self.error = error.localizedDescription
        }
    }

    func loadMoreFollowingWheels() async {
        guard followingWheelsHasMore && !followingWheelsLoadingMore else { return }

        followingWheelsLoadingMore = true
        defer { followingWheelsLoadingMore = false }

        followingWheelsPage += 1

        do {
            let response = try await fetchWheelsWithPagination(
                page: followingWheelsPage, filter: .following)

            if response.data.isEmpty {
                followingWheelsHasMore = false
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.followingWheels.append(contentsOf: response.data)
                }
            }
        } catch {
            followingWheelsPage -= 1  // Откатываем страницу при ошибке
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    private func updateWheelsList(with newWheels: [WheelWithRelations]) {
        // Создаем словарь новых колес для быстрого поиска
        let newWheelsDict = Dictionary(uniqueKeysWithValues: newWheels.map { ($0.id, $0) })

        // Обновляем существующие колеса и добавляем новые
        var updatedWheels = wheels

        for (index, existingWheel) in wheels.enumerated() {
            if let updatedWheel = newWheelsDict[existingWheel.id] {
                // Обновляем существующее колесо
                updatedWheels[index] = updatedWheel
            }
        }

        // Добавляем новые колеса, которых не было в списке
        for newWheel in newWheels {
            if !wheels.contains(where: { $0.id == newWheel.id }) {
                updatedWheels.append(newWheel)
            }
        }

        // Удаляем колеса, которых больше нет на сервере
        updatedWheels = updatedWheels.filter { existingWheel in
            newWheels.contains { $0.id == existingWheel.id }
        }

        // Сортируем по дате создания (новые сверху)
        updatedWheels.sort { $0.createdAt > $1.createdAt }

        // Принудительно обновляем UI с анимацией
        withAnimation(.easeInOut(duration: 0.3)) {
            self.wheels = updatedWheels
        }
    }

    // MARK: - Public Methods

    /// Обновляет конкретное колесо в списке
    func updateWheel(_ updatedWheel: WheelWithRelations) {
        if let index = wheels.firstIndex(where: { $0.id == updatedWheel.id }) {
            wheels[index] = updatedWheel
        }
    }

    /// Добавляет новое колесо в соответствующий список
    func addWheel(_ newWheel: WheelWithRelations) {
        // Добавляем в общий список
        if !wheels.contains(where: { $0.id == newWheel.id }) {
            wheels.append(newWheel)
            wheels.sort { $0.createdAt > $1.createdAt }
        }

        // Добавляем в соответствующий список в зависимости от владельца
        if newWheel.userId == user?.user.id {
            if !myWheels.contains(where: { $0.id == newWheel.id }) {
                myWheels.append(newWheel)
                myWheels.sort { $0.createdAt > $1.createdAt }
            }
        }

        // Добавляем в список всех колес
        if !allWheels.contains(where: { $0.id == newWheel.id }) {
            allWheels.append(newWheel)
            allWheels.sort { $0.createdAt > $1.createdAt }
        }
    }

    /// Удаляет колесо из всех списков
    func removeWheel(withId id: String) {
        wheels.removeAll { $0.id == id }
        myWheels.removeAll { $0.id == id }
        followingWheels.removeAll { $0.id == id }
        allWheels.removeAll { $0.id == id }
    }

    /// Удаляет колесо через API
    func deleteWheel(withId id: String) async {
        do {
            _ = try await deleteWheelFromAPI(id)

            // Удаляем из локального списка
            withAnimation(.easeInOut(duration: 0.3)) {
                self.removeWheel(withId: id)
            }
        } catch is CancellationError {
            // Удаление отменено
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
            self.error = "Ошибка удаления колеса: \(error.localizedDescription)"
        }
    }

    /// Обновляет конкретное колесо по ID
    func updateSpecificWheel(wheelId: String) async {
        // Перезагружаем все секции для обновления данных
        await loadWheels()
    }

    /// Обновляет все секции колес
    func refreshVisibleWheels() async {
        await loadWheels()
    }

    private func deleteWheelFromAPI(_ id: String) async throws -> Wheel {
        return try await FortuneWheelService.shared.deleteWheel(id: id)
    }

    private func fetchWheelsWithPagination(page: Int, filter: WheelFilter? = nil) async throws
        -> WheelListPaginationContent
    {
        return try await FortuneWheelService.shared.getWheelsWithPagination(
            page: page,
            limit: pageSize,
            filter: filter
        )
    }

}
