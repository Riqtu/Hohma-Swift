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
    @Published var errorMessage: String?
    @Published var selectedFilter: WheelFilter = .all // По умолчанию "все"

    // Состояние пагинации
    @Published var hasMore = true
    @Published var isLoadingMore = false

    // Текущая страница
    private var currentPage = 1

    let user: AuthResult?

    // Параметры пагинации
    private let pageSize = 20

    init(user: AuthResult?) {
        self.user = user
        // Инициализируем пустой список
        self.wheels = []
    }

    func loadWheels(showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        currentPage = 1
        hasMore = true

        Task {
            do {
                let response = try await fetchWheelsWithPagination(page: 1, filter: selectedFilter)
                
                await MainActor.run {
                    wheels = response.data
                    hasMore = response.pagination.hasNextPage
                    if showLoading {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                    if showLoading {
                        isLoading = false
                    }
                }
            }
        }
    }

    func refreshWheels() async {
        isRefreshing = true
        defer { isRefreshing = false }

        currentPage = 1
        hasMore = true
        loadWheels(showLoading: false)
    }
    
    func loadMore() async {
        guard hasMore && !isLoadingMore else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        currentPage += 1
        
        do {
            let response = try await fetchWheelsWithPagination(page: currentPage, filter: selectedFilter)
            
            await MainActor.run {
                if response.data.isEmpty {
                    hasMore = false
                } else {
                    let newWheels = response.data.filter { newWheel in
                        !wheels.contains { $0.id == newWheel.id }
                    }
                    wheels.append(contentsOf: newWheels)
                    hasMore = response.pagination.hasNextPage
                }
            }
        } catch {
            await MainActor.run {
                currentPage -= 1
                errorMessage = error.localizedDescription
            }
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
        // Добавляем в список
        if !wheels.contains(where: { $0.id == newWheel.id }) {
            wheels.append(newWheel)
            wheels.sort { $0.createdAt > $1.createdAt }
        }
    }

    /// Удаляет колесо из списка
    func removeWheel(withId id: String) {
        wheels.removeAll { $0.id == id }
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
            self.errorMessage = "Ошибка удаления колеса: \(error.localizedDescription)"
        }
    }

    /// Обновляет конкретное колесо по ID
    func updateSpecificWheel(wheelId: String) async {
        // Перезагружаем список для обновления данных
        loadWheels()
    }

    // MARK: - Private Methods

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
