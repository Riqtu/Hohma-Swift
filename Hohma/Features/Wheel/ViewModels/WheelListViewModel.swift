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
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var paginationInfo: PaginationInfo?

    let apiURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    let user: AuthResult?

    // Параметры пагинации
    private var currentPage = 1
    private let pageSize = 7
    private var hasMorePages = true

    init(user: AuthResult?) {
        self.user = user
    }

    func loadWheels() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await fetchWheelsWithPagination(page: 1)

            // Обновляем список с анимацией
            withAnimation(.easeInOut(duration: 0.3)) {
                self.wheels = response.data
            }

            self.paginationInfo = response.pagination
            self.currentPage = 1
            self.hasMorePages = response.pagination.hasNextPage

        } catch is CancellationError {
            // Загрузка отменена
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Загружает следующую страницу данных
    func loadMoreWheels() async {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPage + 1
            let response = try await fetchWheelsWithPagination(page: nextPage)

            // Добавляем новые колеса к существующим
            withAnimation(.easeInOut(duration: 0.3)) {
                self.wheels.append(contentsOf: response.data)
            }

            self.paginationInfo = response.pagination
            self.currentPage = nextPage
            self.hasMorePages = response.pagination.hasNextPage

        } catch is CancellationError {
            // Загрузка дополнительных данных отменена
        } catch URLError.userAuthenticationRequired {
            // Требуется авторизация
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Принудительно загружает данные, даже если список не пустой
    func forceLoadWheels() async {
        await loadWheels()
    }

    func refreshWheels() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Используем Task.detached для изоляции запроса от отмены
            let response = try await Task.detached(priority: .userInitiated) {
                return try await self.fetchWheelsWithPaginationDirect(page: 1)
            }.value

            // Обновляем список с анимацией
            updateWheelsList(with: response.data)

            self.paginationInfo = response.pagination
            self.currentPage = 1
            self.hasMorePages = response.pagination.hasNextPage

        } catch is CancellationError {
            // Обновление отменено
        } catch URLError.userAuthenticationRequired {
            // 401 ошибка - пользователь будет автоматически перенаправлен на экран авторизации
        } catch {
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

    /// Добавляет новое колесо в список
    func addWheel(_ newWheel: WheelWithRelations) {
        if !wheels.contains(where: { $0.id == newWheel.id }) {
            wheels.append(newWheel)
            // Сортируем по дате создания (новые сверху)
            wheels.sort { $0.createdAt > $1.createdAt }
        }
    }

    /// Удаляет колесо из списка
    func removeWheel(withId id: String) {
        wheels.removeAll { $0.id == id }
    }

    private func fetchWheels() async throws -> [WheelWithRelations] {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.getAll") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Передаём токен
        if let user = user {
            request.setValue("Bearer \(user.token)", forHTTPHeaderField: "Authorization")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withMilliseconds

        let response: WheelListResponse = try await NetworkManager.shared.request(
            request, decoder: decoder)

        return response.result.data.json
    }

    private func fetchWheelsWithPagination(page: Int) async throws -> WheelListPaginationContent {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.getAllWithPagination") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        // Для tRPC query процедур используем GET запрос с параметрами в URL
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        // tRPC ожидает параметры в формате: ?input={"json":{"page":1,"limit":20}}
        let inputData = [
            "json": [
                "page": page,
                "limit": pageSize,
            ]
        ]

        do {
            let inputJSONData = try JSONSerialization.data(withJSONObject: inputData)
            let inputString = String(data: inputJSONData, encoding: .utf8)!
            urlComponents.queryItems = [URLQueryItem(name: "input", value: inputString)]
        } catch {
            throw NSError(
                domain: "NetworkError", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка сериализации JSON"])
        }

        guard let finalURL = urlComponents.url else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"

        // Передаём токен
        if let user = user {
            request.setValue("Bearer \(user.token)", forHTTPHeaderField: "Authorization")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withMilliseconds

        let response: WheelListPaginationResponse = try await NetworkManager.shared.request(
            request, decoder: decoder)

        return response.result.data.json
    }

    // Альтернативный метод для тестирования
    private func fetchWheelsWithPaginationDirect(page: Int) async throws
        -> WheelListPaginationContent
    {
        guard let apiURL = apiURL else {
            throw NSError(
                domain: "NetworkError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "API URL не задан"])
        }

        guard let url = URL(string: "\(apiURL)/wheelList.getAllWithPagination") else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let inputData = ["json": ["page": page, "limit": pageSize]]

        do {
            let inputJSONData = try JSONSerialization.data(withJSONObject: inputData)
            let inputString = String(data: inputJSONData, encoding: .utf8)!
            urlComponents.queryItems = [URLQueryItem(name: "input", value: inputString)]
        } catch {
            throw NSError(
                domain: "NetworkError", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Ошибка сериализации JSON"])
        }

        guard let finalURL = urlComponents.url else {
            throw NSError(
                domain: "NetworkError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "URL некорректный"])
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"

        if let user = user {
            request.setValue("Bearer \(user.token)", forHTTPHeaderField: "Authorization")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withMilliseconds

        // Создаем отдельную URLSession конфигурацию
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        let (data, _) = try await session.data(for: request)

        let responseObject = try decoder.decode(WheelListPaginationResponse.self, from: data)
        return responseObject.result.data.json
    }
}
