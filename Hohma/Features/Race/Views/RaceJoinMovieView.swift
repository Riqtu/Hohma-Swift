import SwiftUI
import Inject

struct RaceJoinMovieView: View {
    @ObserveInjection var inject
    let race: Race
    let onSubmit: (RaceMovieSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var kinopoiskService = KinopoiskService()

    @State private var movieTitle: String = ""
    @State private var searchResults: [KinopoiskMovie] = []
    @State private var selectedMovie: KinopoiskMovie?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingResults: Bool = false
    @FocusState private var isFieldFocused: Bool

    @State private var searchDebouncer: Timer?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Фильм для скачки")
                        .font(.headline)

                    TextField("Введите название фильма", text: $movieTitle)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isFieldFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.thickMaterial)
                        .cornerRadius(12)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UIResponder.keyboardDidShowNotification)
                        ) { _ in
                            // Клавиатура показалась - убеждаемся, что TextField в фокусе
                            if !isFieldFocused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isFieldFocused = true
                                }
                            }
                        }
                        .onChange(of: movieTitle) { _, value in
                            selectedMovie = nil
                            debouncedSearch(query: value)
                        }
                        .submitLabel(.search)

                    if isLoading {
                        ProgressView("Поиск фильмов...")
                            .font(.caption)
                    }
                }

                if showingResults && !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults, id: \.id) { movie in
                                Button {
                                    selectedMovie = movie
                                    movieTitle = movie.name
                                    showingResults = false
                                    cancelSearch()
                                } label: {
                                    MovieSearchRow(
                                        movie: movie, isSelected: selectedMovie?.id == movie.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }

                if let selectedMovie = selectedMovie {
                    SelectedMovieSummary(movie: selectedMovie)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()

                Button(action: submit) {
                    Text("Добавить фильм в скачку")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(movieTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(
                    movieTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
            .padding()
            .navigationTitle(race.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFieldFocused = true
            }
        }
        .onDisappear {
            cancelSearch()
        }
    }

    private func submit() {
        let trimmedTitle = movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let selection = RaceMovieSelection(
            title: trimmedTitle,
            externalId: selectedMovie.map { String($0.id) },
            posterUrl: selectedMovie?.poster?.bestUrl
        )

        onSubmit(selection)
        dismiss()
    }

    private func debouncedSearch(query: String) {
        searchDebouncer?.invalidate()

        guard query.count >= 3 else {
            showingResults = false
            searchResults = []
            return
        }

        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
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
        cancelSearch()

        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let results = try await kinopoiskService.searchMovies(query: query)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.searchResults = results
                    self.showingResults = true
                    self.isLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.errorMessage = "Не удалось выполнить поиск: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

private struct MovieSearchRow: View {
    @ObserveInjection var inject
    let movie: KinopoiskMovie
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let url = movie.poster?.bestUrl.flatMap(URL.init) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name)
                    .font(.headline)
                    .lineLimit(2)

                if let year = movie.year as Int? {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let genre = movie.genres?.first?.name {
                    Text(genre)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct SelectedMovieSummary: View {
    @ObserveInjection var inject
    let movie: KinopoiskMovie

    var body: some View {
        HStack(spacing: 12) {
            if let url = movie.poster?.bestUrl.flatMap(URL.init) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name)
                    .font(.headline)
                if let year = movie.year as Int? {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let desc = movie.shortDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
