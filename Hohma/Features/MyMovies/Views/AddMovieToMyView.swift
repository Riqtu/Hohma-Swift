import Inject
import SwiftUI

struct AddMovieToMyView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = MyMoviesService.shared

    let onMovieAdded: ((MovieSearchDoc) -> Void)?
    let onAddError: ((Int) -> Void)?

    @State private var searchQuery: String = ""
    @State private var searchResults: [MovieSearchDoc] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isAddingMovie: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchDebouncer: Timer?

    init(
        onMovieAdded: ((MovieSearchDoc) -> Void)? = nil,
        onAddError: ((Int) -> Void)? = nil
    ) {
        self.onMovieAdded = onMovieAdded
        self.onAddError = onAddError
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск фильма...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onChange(of: searchQuery) { _, newValue in
                            debouncedSearch(query: newValue)
                        }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            cancelSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                // Результаты поиска
                if isLoading {
                    Spacer()
                    ProgressView("Поиск...")
                        .tint(.accentColor)
                    Spacer()
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Ничего не найдено")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Введите название фильма")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Начните вводить название для поиска")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults) { movie in
                            MovieSearchRow(movie: movie) {
                                addMovie(movie: movie)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .disabled(isAddingMovie)
                            .opacity(isAddingMovie ? 0.6 : 1.0)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if isAddingMovie {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.accentColor)
                                Text("Добавляем фильм...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.2))
                        }
                    }
                }
            }
            .navigationTitle("Добавить фильм")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isAddingMovie)
                }
            }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .withAppBackground()
        }
        .onDisappear {
            cancelSearch()
        }
    }

    private func debouncedSearch(query: String) {
        searchDebouncer?.invalidate()
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchResults = []
            isLoading = false
            return
        }

        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            performSearch(query: query)
        }
    }

    private func cancelSearch() {
        searchDebouncer?.invalidate()
        searchDebouncer = nil
        searchTask?.cancel()
        searchTask = nil
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }

        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let response = try await service.search(query: query, page: 1, limit: 20)
                if Task.isCancelled { return }
                await MainActor.run {
                    searchResults = response.docs
                    isLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func addMovie(movie: MovieSearchDoc) {
        guard !isAddingMovie else { return }

        // Оптимистичное обновление
        onMovieAdded?(movie)

        Task {
            await MainActor.run {
                isAddingMovie = true
                errorMessage = nil
            }

            do {
                _ = try await service.addToMy(
                    kpId: String(movie.id), isWatched: false, userRating: nil)
                if Task.isCancelled { return }
                await MainActor.run {
                    isAddingMovie = false
                    dismiss()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    // Откатываем оптимистичное обновление при ошибке
                    onAddError?(movie.id)
                    errorMessage = "Ошибка добавления фильма: \(error.localizedDescription)"
                    isAddingMovie = false
                }
            }
        }
    }
}

private struct MovieSearchRow: View {
    @ObserveInjection var inject
    let movie: MovieSearchDoc
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                if let posterUrl = movie.poster?.url ?? movie.poster?.previewUrl,
                    let url = URL(string: posterUrl)
                {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                } else {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "film")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.name ?? "Без названия")
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    if let year = movie.year {
                        Text("\(year)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let description = movie.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
