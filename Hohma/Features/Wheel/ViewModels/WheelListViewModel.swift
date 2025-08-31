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
    private let pageSize = 7  // Восстановлено после отладки

    // Ключи для UserDefaults
    private let allWheelsPageKey = "WheelListViewModel.allWheelsPage"
    private let myWheelsPageKey = "WheelListViewModel.myWheelsPage"
    private let followingWheelsPageKey = "WheelListViewModel.followingWheelsPage"
    private let allWheelsHasMoreKey = "WheelListViewModel.allWheelsHasMore"
    private let myWheelsHasMoreKey = "WheelListViewModel.myWheelsHasMore"
    private let followingWheelsHasMoreKey = "WheelListViewModel.followingWheelsHasMore"

    init(user: AuthResult?) {
        self.user = user
        // Инициализируем пустые списки
        self.myWheels = []
        self.followingWheels = []
        self.allWheels = []

        // Восстанавливаем состояние пагинации
        restorePaginationState()
    }

    deinit {
        // Примечание: не можем вызывать MainActor методы в deinit
        // Состояние будет сохранено через другие механизмы
    }

    func loadWheels() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем все три типа колес параллельно с первой страницы
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

            // Обновляем флаги пагинации
            updatePaginationFlags(
                myWheelsCount: myWheels.data.count,
                followingWheelsCount: followingWheels.data.count,
                allWheelsCount: allWheels.data.count
            )

            // Сохраняем обновленное состояние
            savePaginationStateNow()

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

        // Сбрасываем состояние пагинации
        resetPaginationState()

        await loadWheels()
    }

    // MARK: - Пагинация для каждой секции

    func loadMoreAllWheels() async {
        guard allWheelsHasMore && !allWheelsLoadingMore else {
            return
        }

        allWheelsLoadingMore = true
        defer { allWheelsLoadingMore = false }

        allWheelsPage += 1

        // Сохраняем состояние пагинации
        savePaginationStateNow()

        do {
            let response = try await fetchWheelsWithPagination(page: allWheelsPage, filter: .all)

            if response.data.isEmpty {
                allWheelsHasMore = false
                savePaginationStateNow()  // Сохраняем обновленный флаг
            } else {
                // Проверяем, не дублируются ли данные
                let newWheels = response.data.filter { newWheel in
                    !self.allWheels.contains { $0.id == newWheel.id }
                }

                if newWheels.isEmpty {
                    allWheelsHasMore = false
                    savePaginationStateNow()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.allWheels.append(contentsOf: newWheels)
                    }
                }
            }
        } catch {
            allWheelsPage -= 1  // Откатываем страницу при ошибке
            savePaginationStateNow()  // Сохраняем откат
            self.error = error.localizedDescription
        }
    }

    func loadMoreMyWheels() async {
        guard myWheelsHasMore && !myWheelsLoadingMore else {
            return
        }

        // Защита от зацикливания - максимум 20 страниц
        guard myWheelsPage < 20 else {
            myWheelsHasMore = false
            savePaginationStateNow()
            return
        }

        myWheelsLoadingMore = true
        defer { myWheelsLoadingMore = false }

        myWheelsPage += 1

        // Сохраняем состояние пагинации
        savePaginationStateNow()

        do {
            let response = try await fetchWheelsWithPagination(page: myWheelsPage, filter: .my)

            if response.data.isEmpty {
                myWheelsHasMore = false
                savePaginationStateNow()  // Сохраняем обновленный флаг
            } else {
                // Проверяем, не дублируются ли данные
                let newWheels = response.data.filter { newWheel in
                    !self.myWheels.contains { $0.id == newWheel.id }
                }

                if newWheels.isEmpty {
                    myWheelsHasMore = false
                    savePaginationStateNow()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.myWheels.append(contentsOf: newWheels)
                    }
                }
            }
        } catch {
            myWheelsPage -= 1  // Откатываем страницу при ошибке
            savePaginationStateNow()  // Сохраняем откат
            self.error = error.localizedDescription
        }
    }

    func loadMoreFollowingWheels() async {
        guard followingWheelsHasMore && !followingWheelsLoadingMore else {
            return
        }

        // Защита от зацикливания - максимум 20 страниц
        guard followingWheelsPage < 20 else {
            followingWheelsHasMore = false
            savePaginationStateNow()
            return
        }

        followingWheelsLoadingMore = true
        defer { followingWheelsLoadingMore = false }

        followingWheelsPage += 1

        // Сохраняем состояние пагинации
        savePaginationStateNow()

        do {
            let response = try await fetchWheelsWithPagination(
                page: followingWheelsPage, filter: .following)

            if response.data.isEmpty {
                followingWheelsHasMore = false
                savePaginationStateNow()  // Сохраняем обновленный флаг
            } else {
                // Проверяем, не дублируются ли данные
                let newWheels = response.data.filter { newWheel in
                    !self.followingWheels.contains { $0.id == newWheel.id }
                }

                if newWheels.isEmpty {
                    followingWheelsHasMore = false
                    savePaginationStateNow()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.followingWheels.append(contentsOf: newWheels)
                    }
                }
            }
        } catch {
            followingWheelsPage -= 1  // Откатываем страницу при ошибке
            savePaginationStateNow()  // Сохраняем откат
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    /// Устанавливает флаги пагинации на основе количества загруженных данных
    private func updatePaginationFlags(
        myWheelsCount: Int, followingWheelsCount: Int, allWheelsCount: Int
    ) {
        self.myWheelsHasMore = myWheelsCount >= self.pageSize
        self.followingWheelsHasMore = followingWheelsCount >= self.pageSize
        self.allWheelsHasMore = allWheelsCount >= self.pageSize
    }

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

    /// Умная загрузка - загружает только первую страницу, не перезаписывая состояние пагинации
    func loadWheelsSmart() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем все три типа колес параллельно с первой страницы
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

            // Обновляем флаги пагинации
            updatePaginationFlags(
                myWheelsCount: myWheels.data.count,
                followingWheelsCount: followingWheels.data.count,
                allWheelsCount: allWheels.data.count
            )

            // Сохраняем обновленное состояние
            savePaginationStateNow()

        } catch is CancellationError {
            // Загрузка отменена
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Умная загрузка с автоматической дозагрузкой - восстанавливает состояние и дозагружает если нужно
    func loadWheelsSmartWithAutoLoad() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Загружаем все три типа колес параллельно с первой страницы
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

            // Обновляем флаги пагинации
            updatePaginationFlags(
                myWheelsCount: myWheels.data.count,
                followingWheelsCount: followingWheels.data.count,
                allWheelsCount: allWheels.data.count
            )

            // Сохраняем обновленное состояние
            savePaginationStateNow()

            // АВТОМАТИЧЕСКАЯ ДОЗАГРУЗКА: если есть сохраненные страницы > 1, дозагружаем их
            await autoLoadSavedPages()

        } catch is CancellationError {
            // Загрузка отменена
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Автоматически дозагружает сохраненные страницы
    private func autoLoadSavedPages() async {
        // Дозагружаем все секции последовательно, чтобы избежать проблем с MainActor
        await autoLoadSection(
            currentPage: myWheelsPage,
            hasMore: myWheelsHasMore,
            filter: .my
        )

        await autoLoadSection(
            currentPage: followingWheelsPage,
            hasMore: followingWheelsHasMore,
            filter: .following
        )

        await autoLoadSection(
            currentPage: allWheelsPage,
            hasMore: allWheelsHasMore,
            filter: .all
        )

        // Сохраняем финальное состояние
        savePaginationStateNow()
    }

    /// Дозагружает одну секцию до сохраненной страницы
    private func autoLoadSection(
        currentPage: Int,
        hasMore: Bool,
        filter: WheelFilter
    ) async {
        guard hasMore && currentPage > 1 else {
            return
        }

        // Загружаем страницы со 2-й до сохраненной
        for page in 2...currentPage {
            do {
                let response = try await fetchWheelsWithPagination(page: page, filter: filter)

                if response.data.isEmpty {
                    await MainActor.run {
                        switch filter {
                        case .my: self.myWheelsHasMore = false
                        case .following: self.followingWheelsHasMore = false
                        case .followers: self.followingWheelsHasMore = false
                        case .all: self.allWheelsHasMore = false
                        }
                    }
                    break
                }

                // Проверяем дублирование
                let newWheels = response.data.filter { newWheel in
                    // Получаем текущий список в зависимости от фильтра
                    let currentWheels: [WheelWithRelations]
                    switch filter {
                    case .my: currentWheels = self.myWheels
                    case .following: currentWheels = self.followingWheels
                    case .followers: currentWheels = self.followingWheels
                    case .all: currentWheels = self.allWheels
                    }

                    return !currentWheels.contains { $0.id == newWheel.id }
                }

                if newWheels.isEmpty {
                    await MainActor.run {
                        switch filter {
                        case .my: self.myWheelsHasMore = false
                        case .following: self.followingWheelsHasMore = false
                        case .followers: self.followingWheelsHasMore = false
                        case .all: self.allWheelsHasMore = false
                        }
                    }
                    break
                }

                // Добавляем новые данные на главном потоке
                await MainActor.run {
                    switch filter {
                    case .my: self.myWheels.append(contentsOf: newWheels)
                    case .following: self.followingWheels.append(contentsOf: newWheels)
                    case .followers: self.followingWheels.append(contentsOf: newWheels)
                    case .all: self.allWheels.append(contentsOf: newWheels)
                    }
                }

            } catch {
                break
            }
        }
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

    // MARK: - Сохранение и восстановление состояния пагинации

    private func savePaginationState() {
        UserDefaults.standard.set(allWheelsPage, forKey: allWheelsPageKey)
        UserDefaults.standard.set(myWheelsPage, forKey: myWheelsPageKey)
        UserDefaults.standard.set(followingWheelsPage, forKey: followingWheelsPageKey)
        UserDefaults.standard.set(allWheelsHasMore, forKey: allWheelsHasMoreKey)
        UserDefaults.standard.set(myWheelsHasMore, forKey: myWheelsHasMoreKey)
        UserDefaults.standard.set(followingWheelsHasMore, forKey: followingWheelsHasMoreKey)
    }

    private func restorePaginationState() {
        // Восстанавливаем страницы, но не меньше 1
        allWheelsPage = max(1, UserDefaults.standard.integer(forKey: allWheelsPageKey))
        myWheelsPage = max(1, UserDefaults.standard.integer(forKey: myWheelsPageKey))
        followingWheelsPage = max(1, UserDefaults.standard.integer(forKey: followingWheelsPageKey))

        // Восстанавливаем флаги "есть еще данные"
        allWheelsHasMore = UserDefaults.standard.bool(forKey: allWheelsHasMoreKey)
        myWheelsHasMore = UserDefaults.standard.bool(forKey: myWheelsHasMoreKey)
        followingWheelsHasMore = UserDefaults.standard.bool(forKey: followingWheelsHasMoreKey)

        // Если это первая загрузка (флаги false), устанавливаем их в true
        if !allWheelsHasMore && !myWheelsHasMore && !followingWheelsHasMore {
            allWheelsHasMore = true
            myWheelsHasMore = true
            followingWheelsHasMore = true
        }
    }

    /// Принудительно сохраняет текущее состояние пагинации
    func savePaginationStateNow() {
        savePaginationState()
    }

    /// Сбрасывает состояние пагинации (используется при полном обновлении)
    func resetPaginationState() {
        allWheelsPage = 1
        myWheelsPage = 1
        followingWheelsPage = 1
        allWheelsHasMore = true
        myWheelsHasMore = true
        followingWheelsHasMore = true

        // Очищаем сохраненное состояние
        UserDefaults.standard.removeObject(forKey: allWheelsPageKey)
        UserDefaults.standard.removeObject(forKey: myWheelsPageKey)
        UserDefaults.standard.removeObject(forKey: followingWheelsPageKey)
        UserDefaults.standard.removeObject(forKey: allWheelsHasMoreKey)
        UserDefaults.standard.removeObject(forKey: myWheelsHasMoreKey)
        UserDefaults.standard.removeObject(forKey: followingWheelsHasMoreKey)
    }

}
