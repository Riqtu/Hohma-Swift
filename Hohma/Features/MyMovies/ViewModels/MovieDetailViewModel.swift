import Foundation
import SwiftUI

@MainActor
final class MovieDetailViewModel: ObservableObject {
    @Published var movie: MovieRecord?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUpdating = false

    private let service = MyMoviesService.shared
    private let movieId: String
    private var updateTask: Task<Void, Never>?
    private var ratingUpdateTimer: Timer?

    init(movieId: String) {
        self.movieId = movieId
    }

    var userMovie: UserMovieRecord? {
        movie?.userMovies?.first
    }

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let data = try await service.getMovie(id: movieId)
                await MainActor.run {
                    movie = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                    isLoading = false
                }
            }
        }
    }

    func toggleWatched() {
        if movie == nil { return }
        let current = userMovie?.isWatched ?? false
        let newValue = !current
        let newRating = newValue ? userMovie?.userRating : nil
        
        // Оптимистичное обновление - всегда выполняется сразу
        updateLocalState(isWatched: newValue, userRating: newRating)
        
        // Отменяем предыдущий запрос, если он еще выполняется
        updateTask?.cancel()
        
        // Отправка на сервер в фоне
        update(isWatched: newValue, userRating: newRating)
    }

    func updateRating(_ rating: Int) {
        // Оптимистичное обновление - всегда выполняется сразу
        updateLocalState(isWatched: true, userRating: rating)
        
        // Отменяем предыдущий таймер
        ratingUpdateTimer?.invalidate()
        
        // Debounce: отправляем запрос на сервер через 0.3 секунды после последнего изменения
        ratingUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Отменяем предыдущий запрос, если он еще выполняется
            self.updateTask?.cancel()
            // Отправка на сервер в фоне
            self.update(isWatched: true, userRating: rating)
        }
    }
    
    private func updateLocalState(isWatched: Bool?, userRating: Int?) {
        guard var currentMovie = movie else { return }
        
        if let existingUserMovie = currentMovie.userMovies?.first {
            // Определяем новое значение isWatched
            let newIsWatched = isWatched ?? existingUserMovie.isWatched
            
            // Для userRating: если передано конкретное значение (включая 0), используем его
            // Если nil, сохраняем старое значение только если isWatched не меняется на false
            let newUserRating: Int?
            if let rating = userRating {
                // Передано конкретное значение (может быть 0)
                newUserRating = rating
            } else if !newIsWatched {
                // Если снимаем галочку "просмотрено", убираем оценку
                newUserRating = nil
            } else {
                // Сохраняем старое значение
                newUserRating = existingUserMovie.userRating
            }
            
            // Создаем обновленную запись
            let updatedUserMovie = UserMovieRecord(
                id: existingUserMovie.id,
                isWatched: newIsWatched,
                userRating: newUserRating,
                createdAt: existingUserMovie.createdAt,
                updatedAt: existingUserMovie.updatedAt
            )
            currentMovie.userMovies = [updatedUserMovie]
        } else {
            // Создаем новую запись, если её нет
            let newUserMovie = UserMovieRecord(
                id: UUID().uuidString,
                isWatched: isWatched ?? false,
                userRating: userRating,
                createdAt: "",
                updatedAt: ""
            )
            currentMovie.userMovies = [newUserMovie]
        }
        
        movie = currentMovie
    }

    private func update(isWatched: Bool?, userRating: Int?) {
        // Сохраняем текущее состояние для отката в случае ошибки
        let previousMovie = movie
        
        // Отменяем предыдущую задачу, если она еще выполняется
        updateTask?.cancel()
        
        isUpdating = true
        updateTask = Task {
            do {
                let result = try await service.updateMy(
                    movieId: movieId,
                    isWatched: isWatched,
                    userRating: userRating
                )
                
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }
                
                await MainActor.run {
                    var updatedMovie = result.movie
                    updatedMovie.userMovies = [result.userMovie]
                    movie = updatedMovie
                    isUpdating = false
                }
            } catch {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }
                
                await MainActor.run {
                    // Откатываем изменения в случае ошибки
                    if let previous = previousMovie {
                        movie = previous
                    }
                    errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                    isUpdating = false
                }
            }
        }
    }

    func removeFromMy(onRemoved: @escaping () -> Void) {
        isUpdating = true
        Task {
            do {
                try await service.removeFromMy(movieId: movieId)
                await MainActor.run {
                    isUpdating = false
                    onRemoved()
                }
            } catch {
                await MainActor.run {
                    errorMessage = ErrorHandler.shared.handle(error, context: #function, category: .general)
                    isUpdating = false
                }
            }
        }
    }
}

