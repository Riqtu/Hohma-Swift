//
//  AddSectorFormView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Combine
import Inject
import SwiftUI
import UIKit

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

    // Добавляем дебаунсинг для поиска
    @State private var searchDebouncer: Timer?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool

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

                // Поле поиска фильма
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Название фильма")
                            .font(.headline)

                        Spacer()

                        // Кнопка для принудительного фокуса (помощь для iPad)
                        Button(action: {
                            isTextFieldFocused = true
                            // Дополнительная попытка показать клавиатуру
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }
                        }) {
                            Image(systemName: "keyboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text("Введите название фильма для поиска или просто название для добавления")
                        .font(.caption)
                        .foregroundColor(.gray)

                    TextField("Например: Титаник или любой фильм", text: $movieTitle)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(.thickMaterial)
                        .cornerRadius(12)
                        .keyboardType(.default)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onReceive(
                            NotificationCenter.default.publisher(
                                for: UIResponder.keyboardDidShowNotification)
                        ) { _ in
                            // Клавиатура показалась - убеждаемся, что TextField в фокусе
                            if !isTextFieldFocused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }
                        }
                        .onChange(of: movieTitle) { _, newValue in
                            debouncedSearch(query: newValue)
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
                                        // Отменяем поиск при выборе фильма
                                        cancelSearch()
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
                            .foregroundColor(.white)
                        Text("Добавить сектор")
                            .foregroundColor(.white)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("AccentColor"))
                    .cornerRadius(12)
                }
                .disabled(movieTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(
                    movieTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(20)
            .appBackground(useVideo: false)
            // .navigationTitle("Добавить сектор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(accentColorUI)
                }
            }
            .enableInjection()
            .onAppear {
                // Автоматически фокусируемся на TextField при появлении
                // Увеличиваем задержку для более надежной работы на iPad
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }

                // Дополнительная попытка фокуса через 1 секунду для iPad
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !isTextFieldFocused {
                        isTextFieldFocused = true
                    }
                }

                // Подписываемся на уведомления о клавиатуре
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Клавиатура показывается - убеждаемся, что TextField в фокусе
                    if !isTextFieldFocused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                }

                // Проверяем доступность клавиатуры
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if !isTextFieldFocused {
                        // Если клавиатура все еще не открылась, показываем дополнительную подсказку
                        print("⚠️ Клавиатура не открылась автоматически на iPad")

                        // Попытка принудительного фокуса
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isTextFieldFocused = true
                        }
                    }
                }
            }
            .onDisappear {
                // Очищаем ресурсы при закрытии
                cancelSearch()

                // Удаляем наблюдатель уведомлений
                NotificationCenter.default.removeObserver(
                    self,
                    name: UIResponder.keyboardWillShowNotification,
                    object: nil
                )
            }
            // Улучшенная обработка клавиатуры
            .onTapGesture {
                // Скрываем клавиатуру при тапе вне TextField
                if isTextFieldFocused {
                    isTextFieldFocused = false
                }
            }
        }
    }

    // MARK: - Private Methods

    private func debouncedSearch(query: String) {
        // Отменяем предыдущий таймер
        searchDebouncer?.invalidate()

        // Отменяем предыдущую задачу поиска
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchResults = []
            showingSearchResults = false
            isLoading = false
            return
        }

        // Создаем новый таймер с задержкой 500ms
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
        guard query.count >= 2 else {
            searchResults = []
            showingSearchResults = false
            return
        }

        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let results = try await kinopoiskService.searchMovies(query: query)

                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }

                await MainActor.run {
                    searchResults = results
                    showingSearchResults = true
                    isLoading = false
                }
            } catch {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled { return }

                await MainActor.run {
                    errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func addSector() {
        guard let currentUser = currentUser else { return }

        let trimmedTitle = movieTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        // Создаем случайный цвет для сектора
        let randomColor = ColorJSON(
            h: Double.random(in: 0...360),
            s: Double.random(in: 60...100),
            l: Double.random(in: 40...70)
        )

        // Создаем сектор
        let sector = Sector(
            id: UUID().uuidString,  // Временный ID, будет заменен сервером
            label: selectedMovie?.name ?? trimmedTitle,
            color: randomColor,
            name: currentUser.firstName ?? currentUser.username ?? "Unknown",
            eliminated: false,
            winner: false,
            description: selectedMovie?.description,
            pattern: selectedMovie?.poster?.bestUrl,  // Добавляем постер в pattern
            patternPosition: PatternPositionJSON(x: 0, y: 0, z: 0),
            poster: selectedMovie?.poster?.bestUrl,
            genre: selectedMovie?.genres?.first?.name,
            rating: nil,
            year: selectedMovie != nil ? String(selectedMovie!.year) : nil,
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
                if let posterUrl = movie.poster?.bestUrl,
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
            if let posterUrl = movie.poster?.bestUrl,
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
