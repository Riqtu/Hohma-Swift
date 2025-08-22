//
//  AddSectorFormView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct AddSectorFormView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var kinopoiskService = KinopoiskService()

    @State private var movieTitle = ""
    @State private var searchResults: [KinopoiskMovie] = []
    @State private var isLoading = false
    @State private var selectedMovie: KinopoiskMovie?
    @State private var showingSearchResults = false
    @State private var errorMessage: String?

    let wheelId: String
    let currentUser: AuthUser?
    let accentColor: String
    let onSectorCreated: (Sector) -> Void

    private var accentColorUI: Color {
        Color(hex: accentColor)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("Добавить фильм")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Поле поиска фильма
                VStack(alignment: .leading, spacing: 8) {
                    Text("Название фильма")
                        .font(.headline)
                        .foregroundColor(.white)

                    TextField("Введите название фильма", text: $movieTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: movieTitle) { _, newValue in
                            searchMovies(query: newValue)
                        }

                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Поиск фильмов...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Результаты поиска
                if showingSearchResults && !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults, id: \.id) { movie in
                                MovieSearchResultRow(
                                    movie: movie,
                                    accentColor: accentColor,
                                    onSelect: { selectedMovie in
                                        self.selectedMovie = selectedMovie
                                        self.movieTitle = selectedMovie.name
                                        self.showingSearchResults = false
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }

                // Выбранный фильм
                if let selectedMovie = selectedMovie {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Выбранный фильм")
                            .font(.headline)
                            .foregroundColor(.white)

                        SelectedMovieCard(movie: selectedMovie, accentColor: accentColor)
                    }
                }

                // Сообщение об ошибке
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Кнопка добавления
                Button(action: addSector) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Добавить сектор")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColorUI)
                    .cornerRadius(12)
                }
                .disabled(selectedMovie == nil)
                .opacity(selectedMovie == nil ? 0.5 : 1.0)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Добавить сектор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(accentColorUI)
                }
            }
        }
        .enableInjection()
    }

    // MARK: - Private Methods

    private func searchMovies(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            showingSearchResults = false
            return
        }

        Task {
            isLoading = true
            do {
                let results = try await kinopoiskService.searchMovies(query: query)
                await MainActor.run {
                    searchResults = results
                    showingSearchResults = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func addSector() {
        guard let selectedMovie = selectedMovie,
            let currentUser = currentUser
        else { return }

        // Создаем случайный цвет для сектора
        let randomColor = ColorJSON(
            h: Double.random(in: 0...360),
            s: Double.random(in: 60...100),
            l: Double.random(in: 40...70)
        )

        // Создаем сектор
        let sector = Sector(
            id: UUID().uuidString,  // Временный ID, будет заменен сервером
            label: selectedMovie.name,
            color: randomColor,
            name: currentUser.firstName ?? currentUser.username ?? "Unknown",
            eliminated: false,
            winner: false,
            description: selectedMovie.description,
            pattern: nil,
            patternPosition: PatternPositionJSON(x: 0, y: 0, z: 0),
            poster: selectedMovie.poster?.previewUrl,
            genre: selectedMovie.genres?.first?.name,
            rating: nil,
            year: String(selectedMovie.year),
            labelColor: nil,
            labelHidden: false,
            wheelId: wheelId,
            userId: currentUser.id,
            user: currentUser,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Вызываем колбэк для создания сектора
        onSectorCreated(sector)
        dismiss()
    }
}

// MARK: - Movie Search Result Row

struct MovieSearchResultRow: View {
    let movie: KinopoiskMovie
    let accentColor: String
    let onSelect: (KinopoiskMovie) -> Void

    private var accentColorUI: Color {
        Color(hex: accentColor)
    }

    var body: some View {
        Button(action: { onSelect(movie) }) {
            HStack(spacing: 12) {
                // Постер фильма
                if let posterUrl = movie.poster?.previewUrl,
                    let url = URL(string: posterUrl)
                {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.gray)
                        )
                }

                // Информация о фильме
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("\(movie.year)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    if !(movie.genres?.isEmpty ?? true) {
                        Text(movie.genres?.prefix(2).map { $0.name }.joined(separator: ", ") ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColorUI.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Selected Movie Card

struct SelectedMovieCard: View {
    let movie: KinopoiskMovie
    let accentColor: String

    private var accentColorUI: Color {
        Color(hex: accentColor)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Постер фильма
            if let posterUrl = movie.poster?.previewUrl,
                let url = URL(string: posterUrl)
            {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 120)
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 120)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }

            // Информация о фильме
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text("\(movie.year)")
                    .font(.subheadline)
                    .foregroundColor(accentColorUI)

                if !(movie.genres?.isEmpty ?? true) {
                    Text(movie.genres?.prefix(3).map { $0.name }.joined(separator: ", ") ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                if let description = movie.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColorUI, lineWidth: 2)
        )
    }
}

#Preview {
    AddSectorFormView(
        wheelId: "test-wheel-id",
        currentUser: AuthUser.mock,
        accentColor: "#ff8181",
        onSectorCreated: { _ in }
    )
}
