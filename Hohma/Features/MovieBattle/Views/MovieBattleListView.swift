//
//  MovieBattleListView.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import Inject
import SwiftUI

struct MovieBattleListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = MovieBattleListViewModel()
    @State private var showingCreateBattle = false
    @State private var battleToOpen: MovieBattle?
    @State private var battleToDelete: MovieBattle?
    @State private var showingDeleteAlert = false
    @State private var battleToShare: MovieBattle?

    var body: some View {
        VStack(spacing: 0) {
            // Сегментированный контрол для фильтрации
            Picker("Фильтр", selection: $viewModel.selectedFilter) {
                Text("Все").tag(MovieBattleFilterType.all)
                Text("Мои").tag(MovieBattleFilterType.my)
                Text("Подписки").tag(MovieBattleFilterType.following)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.selectedFilter) { oldValue, newValue in
                viewModel.loadBattles()
            }

            if viewModel.isLoading && viewModel.battles.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Загрузка игр...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.battles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Нет активных игр")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(emptyStateMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.battles) { battle in
                        MovieBattleCard(
                            battle: battle,
                            onOpen: {
                                battleToOpen = battle
                            },
                            onDelete: nil,
                            canDelete: false,
                            onShare: {
                                battleToShare = battle
                            }
                        )
                        .contentShape(Rectangle())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.canDeleteBattle(battle) {
                                Button {
                                    battleToDelete = battle
                                    showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .refreshable {
                    viewModel.loadBattles(showLoading: false)
                }
            }
        }
        .appBackground()
        .navigationTitle("Битва фильмов")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateBattle = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateBattle) {
            CreateMovieBattleView(viewModel: viewModel)
        }
        .fullScreenCover(item: $battleToOpen) { battle in
            MovieBattleView(battleId: battle.id) {
                battleToOpen = nil
                viewModel.loadBattles()
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Удалить игру", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {
                battleToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                if let battle = battleToDelete {
                    Task {
                        await viewModel.deleteBattle(battleId: battle.id)
                    }
                }
                battleToDelete = nil
            }
        } message: {
            Text("Вы уверены, что хотите удалить эту игру? Это действие нельзя отменить.")
        }
        .sheet(item: $battleToShare) { battle in
            ShareBattleToChatView(battle: battle) {
                battleToShare = nil
            }
        }
        .onAppear {
            viewModel.loadBattles()
        }
    }

    // Сообщение для пустого состояния в зависимости от фильтра
    private var emptyStateMessage: String {
        switch viewModel.selectedFilter {
        case .my:
            return "У вас пока нет созданных игр"
        case .following:
            return "Нет игр от пользователей, на которых вы подписаны"
        case .all:
            return "Создайте новую игру или присоединитесь к существующей"
        case .followers:
            // Устаревший фильтр, не должен использоваться
            return "Нет активных игр"
        }
    }
}

// MARK: - MovieBattleCard

struct MovieBattleCard: View {
    @ObserveInjection var inject
    let battle: MovieBattle
    let onOpen: () -> Void
    let onDelete: (() -> Void)?
    let canDelete: Bool
    let onShare: (() -> Void)?

    init(
        battle: MovieBattle, onOpen: @escaping () -> Void, onDelete: (() -> Void)? = nil,
        canDelete: Bool = false, onShare: (() -> Void)? = nil
    ) {
        self.battle = battle
        self.onOpen = onOpen
        self.onDelete = onDelete
        self.canDelete = canDelete
        self.onShare = onShare
    }

    var body: some View {
        // Основной контент
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок с названием и статусом
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(battle.name)
                            .font(.headline)
                            .lineLimit(2)

                        if battle.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Информация о создателе
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(creatorName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                MovieBattleStatusBadge(status: battle.status)
            }

            Divider()
                .padding(.vertical, 4)

            // Основная информация
            VStack(alignment: .leading, spacing: 14) {
                // Участники и фильмы
                HStack(spacing: 16) {
                    Label("\(battle.participantCount)", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Label("\(battle.movieCount)/\(battle.maxMovies)", systemImage: "film.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                // Прогресс сбора фильмов (если идет сбор)
                if battle.status == .collecting || battle.status == .created {
                    ProgressView(
                        value: Double(battle.movieCount), total: Double(battle.maxMovies)
                    )
                    .tint(.blue)
                    .frame(height: 4)
                }

                // Информация о раунде (если идет голосование)
                if battle.status == .voting {
                    HStack {
                        Label(
                            "Раунд \(battle.currentRound)",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if battle.moviesRemaining > 0 {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Осталось: \(battle.moviesRemaining)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Информация о победителе (если батл завершен)
                if battle.status == .finished, let winner = winnerMovie {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Победитель")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }

                        // Сгенерированный вариант
                        WinnerMovieRow(
                            movie: winner,
                            isGenerated: true
                        )

                        Divider()
                            .padding(.vertical, 2)

                        // Оригинальный вариант
                        WinnerMovieRow(
                            movie: winner,
                            isGenerated: false
                        )
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Дата создания - выровнена по правому краю
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(relativeTimeString(from: battle.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            Group {
                // Полупрозрачный постер на фоне для завершенных батлов
                if battle.status == .finished, let posterUrl = winnerPosterUrl, !posterUrl.isEmpty,
                    let url = URL(string: posterUrl)
                {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.2)
                            .blur(radius: 2)
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    } placeholder: {
                        // Анимация загрузки
                        SkeletonLoader(
                            baseColor: .gray.opacity(0.2),
                            shimmerColor: .white.opacity(0.3),
                            duration: 1.5
                        )
                        .opacity(0.3)
                    }
                    .clipped()
                } else {
                    Color.clear
                }
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
        .contextMenu {
            Button(action: {
                onOpen()
            }) {
                Label("Открыть", systemImage: "arrow.right.circle")
            }

            if let onShare = onShare {
                Button(action: {
                    onShare()
                }) {
                    Label("Поделиться в чате", systemImage: "paperplane")
                }
            }
        }
    }

    // Получаем фильм-победитель
    private var winnerMovie: MovieCard? {
        guard let movies = battle.movies, !movies.isEmpty else { return nil }
        return movies.first(where: { $0.finalPosition == 1 })
    }

    // Получаем постер победителя или первого фильма с постером
    private var winnerPosterUrl: String? {
        guard let movies = battle.movies, !movies.isEmpty else { return nil }

        // Сначала ищем победителя с постером
        if let winner = movies.first(where: { $0.finalPosition == 1 }) {
            if let generatedPoster = winner.generatedPosterUrl, !generatedPoster.isEmpty {
                return generatedPoster
            }
            if let originalPoster = winner.originalPosterUrl, !originalPoster.isEmpty {
                return originalPoster
            }
        }

        // Если победителя нет или у него нет постера, берем первый фильм с постером
        for movie in movies {
            if let generatedPoster = movie.generatedPosterUrl, !generatedPoster.isEmpty {
                return generatedPoster
            }
            if let originalPoster = movie.originalPosterUrl, !originalPoster.isEmpty {
                return originalPoster
            }
        }

        return nil
    }

    private var creatorName: String {
        battle.creator.name ?? battle.creator.username ?? "Неизвестный"
    }

    private func relativeTimeString(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"

        guard let date = formatter.date(from: dateString) else {
            // Fallback без миллисекунд
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelativeTime(from: date)
        }

        return formatRelativeTime(from: date)
    }

    private func formatRelativeTime(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.minute, .hour, .day, .weekOfYear, .month], from: date, to: now)

        if let month = components.month, month > 0 {
            return "\(month) \(month == 1 ? "месяц" : month < 5 ? "месяца" : "месяцев") назад"
        } else if let week = components.weekOfYear, week > 0 {
            return "\(week) \(week == 1 ? "неделю" : week < 5 ? "недели" : "недель") назад"
        } else if let day = components.day, day > 0 {
            if day == 1 {
                return "Вчера"
            }
            return "\(day) \(day < 5 ? "дня" : "дней") назад"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) \(hour == 1 ? "час" : hour < 5 ? "часа" : "часов") назад"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) \(minute == 1 ? "минуту" : minute < 5 ? "минуты" : "минут") назад"
        } else {
            return "Только что"
        }
    }
}

// MARK: - WinnerMovieRow

struct WinnerMovieRow: View {
    @ObserveInjection var inject
    let movie: MovieCard
    let isGenerated: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Постер
            let posterUrl =
                isGenerated
                ? (movie.generatedPosterUrl ?? movie.originalPosterUrl) : movie.originalPosterUrl
            if let posterUrl = posterUrl, !posterUrl.isEmpty, let url = URL(string: posterUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(width: 40, height: 60)
                .cornerRadius(6)
            } else {
                Image(systemName: "film")
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }

            // Информация о фильме
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(isGenerated ? "🎬" : "📽️")
                        .font(.caption2)
                    Text(isGenerated ? "Сгенерированный" : "Оригинальный")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(isGenerated ? movie.displayTitle : movie.originalTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let description = isGenerated
                    ? movie.displayDescription : movie.originalDescription
                {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

// MARK: - MovieBattleStatusBadge

struct MovieBattleStatusBadge: View {
    @ObserveInjection var inject
    let status: MovieBattleStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(6)
    }

    var statusColor: Color {
        switch status {
        case .created, .collecting:
            return .blue
        case .generating:
            return .orange
        case .voting:
            return .green
        case .finished:
            return .gray
        case .cancelled:
            return .red
        }
    }
}

// MARK: - CreateMovieBattleView

struct CreateMovieBattleView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String = "Тайный фильм"
    @State private var minMovies: Int = 2
    @State private var maxMovies: Int = 8
    @State private var minParticipants: Int = 1
    @State private var isPrivate: Bool = false
    @State private var useVotingTimer: Bool = false
    @State private var votingTimeSeconds: Int = 60

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Настройки игры")) {
                    TextField("Название", text: $name)
                    Stepper("Минимум фильмов: \(minMovies)", value: $minMovies, in: 2...20)
                    Stepper("Максимум фильмов: \(maxMovies)", value: $maxMovies, in: 2...20)
                    Stepper(
                        "Минимум участников: \(minParticipants)", value: $minParticipants,
                        in: 1...20)
                    Toggle("Таймер голосования", isOn: $useVotingTimer)
                    if useVotingTimer {
                        Stepper(
                            "Время на раунд: \(votingTimeSeconds) сек",
                            value: $votingTimeSeconds,
                            in: 10...300,
                            step: 10
                        )
                    }
                    Toggle("Приватная игра", isOn: $isPrivate)
                }
            }
            .navigationTitle("Создать игру")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        let request = CreateMovieBattleRequest(
                            name: name,
                            minMovies: minMovies,
                            maxMovies: maxMovies,
                            minParticipants: minParticipants,
                            votingTimeSeconds: useVotingTimer ? votingTimeSeconds : nil,
                            isPrivate: isPrivate
                        )
                        Task {
                            await viewModel.createBattle(request: request)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .appBackground()
        }
    }
}

// MARK: - MovieBattleListViewModel

@MainActor
class MovieBattleListViewModel: ObservableObject, TRPCServiceProtocol {
    @Published var battles: [MovieBattle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: MovieBattleFilterType = .all  // По умолчанию "все"

    private let service = MovieBattleService.shared

    func loadBattles(showLoading: Bool = true) {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                // Передаем выбранный фильтр (nil на бэкенде также означает "все")
                let filterType: MovieBattleFilterType? =
                    selectedFilter == .all ? nil : selectedFilter

                let loadedBattles = try await service.getBattles(
                    status: nil,
                    isPrivate: nil,
                    filterType: filterType,
                    limit: 50,
                    offset: 0,
                    includeMovies: true
                )

                // Проверяем, не была ли задача отменена
                if Task.isCancelled {
                    if showLoading {
                        isLoading = false
                    }
                    return
                }

                // Обновляем напрямую, так как ViewModel уже @MainActor
                battles = loadedBattles
                if showLoading {
                    isLoading = false
                }
            } catch is CancellationError {
                // Загрузка отменена - это нормально при refresh
                if showLoading {
                    isLoading = false
                }
                return
            } catch {
                // Проверяем, не была ли задача отменена
                if Task.isCancelled {
                    if showLoading {
                        isLoading = false
                    }
                    return
                }

                // Игнорируем ошибки отмены запроса (это нормально при навигации/рефреше)
                // Проверяем разные варианты обертки ошибки
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    if showLoading {
                        isLoading = false
                    }
                    return
                }

                // Проверяем NSError с кодом -999 (отменено)
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                    if showLoading {
                        isLoading = false
                    }
                    return
                }

                // Проверяем описание ошибки на наличие "отменено"
                let errorDescription = error.localizedDescription.lowercased()
                if errorDescription.contains("отменено") || errorDescription.contains("cancelled") {
                    if showLoading {
                        isLoading = false
                    }
                    return
                }

                errorMessage = "Ошибка загрузки игр: \(error.localizedDescription)"
                if showLoading {
                    isLoading = false
                }
            }
        }
    }

    func createBattle(request: CreateMovieBattleRequest) async {
        isLoading = true
        errorMessage = nil

        do {
            let createdBattle = try await service.createBattle(request)

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            battles.insert(createdBattle, at: 0)
            isLoading = false
        } catch {
            // Игнорируем ошибки отмены запроса
            if let urlError = error as? URLError, urlError.code == .cancelled {
                isLoading = false
                return
            }

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            errorMessage = "Ошибка создания игры: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func deleteBattle(battleId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await service.deleteBattle(battleId: battleId)

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            // Удаляем из списка
            battles.removeAll { $0.id == battleId }
            isLoading = false
        } catch {
            // Игнорируем ошибки отмены запроса
            if let urlError = error as? URLError, urlError.code == .cancelled {
                isLoading = false
                return
            }

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            errorMessage = "Ошибка удаления игры: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func canDeleteBattle(_ battle: MovieBattle) -> Bool {
        guard let currentUserId = trpcService.currentUser?.id else { return false }
        // Можно удалять только свои батлы на любом этапе (любой статус)
        return battle.creator.id == currentUserId
    }
}
