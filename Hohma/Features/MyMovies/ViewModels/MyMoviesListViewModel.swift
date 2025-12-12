import Foundation
import SwiftUI

@MainActor
final class MyMoviesListViewModel: ObservableObject {
    @Published var items: [MyMovieListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var page: Int = 1
    @Published var canLoadMore = true

    private let service = MyMoviesService.shared
    private let pageSize = 20

    /// Загрузка с опциональным сбросом страницы. При refresh можно не очищать текущий список.
    func load(reset: Bool = false, clearItems: Bool = false) {
        if reset {
            page = 1
            canLoadMore = true
            if clearItems {
                items = []
            }
        }
        guard canLoadMore else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await service.myMovies(page: page, limit: pageSize)
                await MainActor.run {
                    if reset {
                        items = response.items
                    } else {
                        items.append(contentsOf: response.items)
                    }
                    canLoadMore = page < response.pages
                    if canLoadMore { page += 1 }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func remove(item: MyMovieListItem) {
        Task {
            do {
                try await service.removeFromMy(movieId: item.movieId)
                await MainActor.run {
                    items.removeAll { $0.id == item.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Оптимистичное добавление фильма в список
    func addMovieOptimistically(from searchDoc: MovieSearchDoc) {
        // Создаем временный элемент из данных поиска
        let tempMovie = MovieRecord(
            id: "temp_\(searchDoc.id)",
            kpId: String(searchDoc.id),
            imdbId: nil,
            tmdbId: nil,
            kpHdId: nil,
            type: nil,
            name: searchDoc.name,
            alternativeName: searchDoc.alternativeName,
            enName: nil,
            year: searchDoc.year,
            description: searchDoc.description,
            shortDescription: nil,
            movieLength: nil,
            isSeries: nil,
            ticketsOnSale: nil,
            totalSeriesLength: nil,
            seriesLength: nil,
            ratingMpaa: nil,
            ageRating: nil,
            top10: nil,
            top250: nil,
            typeNumber: nil,
            status: nil,
            posterUrl: searchDoc.poster?.url,
            posterPreviewUrl: searchDoc.poster?.previewUrl,
            backdropUrl: nil,
            backdropPreviewUrl: nil,
            logoUrl: nil,
            logoPreviewUrl: nil,
            ratingKp: nil,
            ratingImdb: nil,
            ratingFilmCritics: nil,
            ratingRussianFilmCritics: nil,
            ratingAwait: nil,
            votesKp: nil,
            votesImdb: nil,
            votesFilmCritics: nil,
            votesRussianFilmCritics: nil,
            votesAwait: nil,
            names: nil,
            genres: nil,
            countries: nil,
            releaseYears: nil,
            userMovies: []
        )
        
        _ = UserMovieRecord(
            id: "temp_user_\(searchDoc.id)",
            isWatched: false,
            userRating: nil,
            createdAt: "",
            updatedAt: ""
        )
        
        let tempItem = MyMovieListItem(
            id: "temp_\(searchDoc.id)",
            movieId: "temp_\(searchDoc.id)",
            userId: "",
            isWatched: false,
            userRating: nil,
            createdAt: "",
            updatedAt: "",
            movie: tempMovie
        )
        
        // Добавляем в начало списка
        items.insert(tempItem, at: 0)
    }
    
    /// Удаляет временный элемент и обновляет список после успешного добавления
    func refreshAfterAdd() {
        // Удаляем все временные элементы
        items.removeAll { $0.id.hasPrefix("temp_") }
        // Обновляем список с сервера
        load(reset: true, clearItems: false)
    }
    
    /// Откатывает оптимистичное добавление при ошибке
    func rollbackAdd(movieId: Int) {
        items.removeAll { $0.id == "temp_\(movieId)" }
    }
}

