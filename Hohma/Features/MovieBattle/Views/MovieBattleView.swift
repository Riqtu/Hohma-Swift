//
//  MovieBattleView.swift
//  Hohma
//
//  Created by Assistant
//

import Inject
import SwiftUI

struct MovieBattleView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = MovieBattleViewModel()
    let battleId: String?
    let onDismiss: (() -> Void)?

    init(battleId: String? = nil, onDismiss: (() -> Void)? = nil) {
        self.battleId = battleId
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.battle == nil {
                    ProgressView("Загрузка...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Ошибка")
                            .font(.title)
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                } else if viewModel.battle != nil {
                    phaseView
                        .refreshable {
                            if let battleId = battleId {
                                await viewModel.loadBattle(id: battleId)
                            }
                        }
                } else {
                    Text("Игра не найдена")
                }
            }
            .navigationTitle(viewModel.battle?.name ?? "Movie Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Назад") {
                        onDismiss?()
                    }
                }
            }
        }
        .task {
            if let battleId = battleId {
                await viewModel.loadBattle(id: battleId)
            }
        }
    }

    @ViewBuilder
    private var phaseView: some View {
        ZStack {
            switch viewModel.currentPhase {
            case .collecting:
                CollectingMoviesView(viewModel: viewModel)
                    .id("collecting")
            case .generating:
                GeneratingView(viewModel: viewModel)
                    .id("generating")
            case .voting:
                VotingView(viewModel: viewModel)
                    .id("voting")
            case .roundResult:
                RoundResultView(viewModel: viewModel)
                    .id("roundResult")
            case .finished:
                MovieBattleWinnerView(viewModel: viewModel)
                    .id("finished")
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.currentPhase)
    }
}

// MARK: - Collecting Movies Phase

struct CollectingMoviesView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Заголовок
                VStack(alignment: .leading) {
                    Text("Сбор фильмов")
                        .font(.largeTitle)
                        .bold()

                    if let battle = viewModel.battle {
                        if viewModel.isParticipant {
                            // Для создателя показываем общее количество фильмов, для участников - только свои
                            let totalMovies = battle._count?.movies ?? battle.movies?.count ?? 0
                            let displayedMovies =
                                viewModel.isCreator ? totalMovies : (battle.movies?.count ?? 0)
                            Text("\(displayedMovies) / \(battle.maxMovies) фильмов")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Для неучастников показываем общую информацию
                            let participantCount = battle.participantCount
                            let totalMovies = battle._count?.movies ?? 0
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Участников: \(participantCount)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Фильмов: \(totalMovies) / \(battle.maxMovies)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()

                // Кнопка присоединения к игре
                if viewModel.canJoinBattle {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Вы не участвуете в этой игре")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(
                                "Присоединитесь, чтобы добавлять фильмы и участвовать в голосовании"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        }
                        .padding(.vertical)

                        Button(action: {
                            Task {
                                await viewModel.joinBattle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Присоединиться к игре")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("AccentColor"))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }

                // Список фильмов (показывается только для участников)
                if viewModel.isParticipant {
                    if let movies = viewModel.battle?.movies, !movies.isEmpty {
                        LazyVStack(spacing: 10) {
                            ForEach(movies) { movie in
                                MovieCardRow(
                                    movie: movie,
                                    showOriginalTitle: true,
                                    showGenerationStatus: true,
                                    showOriginalData: true
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "film.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("Фильмы еще не добавлены")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Добавьте фильмы, чтобы начать игру")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }

                // Кнопка добавления фильма (только для участников)
                if viewModel.canAddMovie && viewModel.isParticipant {
                    Button(action: {
                        viewModel.showingAddMovieSheet = true
                    }) {
                        Text("Добавить фильм")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("AccentColor").opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                // Информация о требованиях для начала игры
                if let battle = viewModel.battle,
                    viewModel.isCreator
                {
                    let participantCount = battle.participants?.count ?? 0
                    // Используем общее количество фильмов из _count для проверки
                    let totalMovieCount = battle._count?.movies ?? battle.movies?.count ?? 0
                    let hasEnoughParticipants =
                        battle.minParticipants <= 1 || participantCount >= battle.minParticipants
                    let hasEnoughMovies = totalMovieCount >= battle.minMovies

                    if !hasEnoughParticipants || !hasEnoughMovies {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Для начала игры нужно:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            // Показываем требование об участниках только если minParticipants > 1
                            if battle.minParticipants > 1 {
                                HStack {
                                    Image(
                                        systemName: hasEnoughParticipants
                                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                                    )
                                    .foregroundColor(hasEnoughParticipants ? .green : .red)
                                    Text(
                                        "Участников: \(participantCount) / \(battle.minParticipants)"
                                    )
                                    .font(.caption)
                                }
                            }

                            HStack {
                                Image(
                                    systemName: hasEnoughMovies
                                        ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .foregroundColor(hasEnoughMovies ? .green : .red)
                                Text("Фильмов: \(totalMovieCount) / \(battle.minMovies)")
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    }
                }

                // Кнопка начала игры
                if viewModel.canStartBattle {
                    Button(action: {
                        Task {
                            await viewModel.startBattle()
                        }
                    }) {
                        Text("Начать игру")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("AccentColor"))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .appBackground()
        .sheet(isPresented: $viewModel.showingAddMovieSheet) {
            AddMovieView(viewModel: viewModel)
        }
    }
}

// MARK: - Generating Phase

struct GeneratingView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var generatedCount: Int {
        viewModel.battle?.movies?.filter { $0.generationStatus == .completed }.count ?? 0
    }

    var totalCount: Int {
        viewModel.battle?.movies?.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок с прогрессом
                VStack(spacing: 8) {
                    Text("Генерация постеров и описаний...")
                        .font(.title)
                        .bold()

                    Text("\(generatedCount) / \(totalCount) сгенерировано")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if totalCount > 0 {
                        ProgressView(value: Double(generatedCount), total: Double(totalCount))
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                            .padding(.horizontal)
                    }
                }
                .padding()

                // Список фильмов с прогрессом
                if let movies = viewModel.battle?.movies {
                    LazyVStack(spacing: 16) {
                        ForEach(movies) { movie in
                            VStack(alignment: .leading, spacing: 8) {
                                // Если фильм сгенерирован, показываем его карточку
                                if movie.generationStatus == .completed {
                                    MovieCardRow(movie: movie)
                                } else {
                                    // Иначе показываем прогресс
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            // Показываем название только если оно сгенерировано
                                            if movie.hasGeneratedTitle {
                                                Text(movie.displayTitle)
                                                    .font(.headline)
                                            } else {
                                                Text("Генерация названия...")
                                                    .font(.headline)
                                                    .foregroundColor(.secondary)
                                            }

                                            if let progress = viewModel.generationProgress[movie.id]
                                            {
                                                ProgressView(value: progress.progress)
                                                    .progressViewStyle(LinearProgressViewStyle())
                                                Text(progress.status.displayName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("Ожидание...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if let progress = viewModel.generationProgress[movie.id] {
                                            if progress.status == .generating
                                                || progress.status == .titleReady
                                                || progress.status == .posterReady
                                                || progress.status == .descriptionReady
                                            {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else if progress.status == .completed {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            } else if progress.status == .failed {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .appBackground()
    }
}

// MARK: - Voting Phase

struct VotingView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var body: some View {
        ZStack {
            // Если пользователь уже проголосовал, показываем экран ожидания
            if viewModel.votingProgress?.hasVoted == true {
                VotingWaitingView(viewModel: viewModel)
                    .id("waiting")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Показываем экран голосования
                VotingSelectionView(viewModel: viewModel)
                    .id("selection")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.5, dampingFraction: 0.85),
            value: viewModel.votingProgress?.hasVoted ?? false)
    }
}

// MARK: - Voting Selection View

struct VotingSelectionView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel
    @State private var currentPage: Int = 0

    var body: some View {
        let movies = viewModel.remainingMovies

        if !movies.isEmpty {
            ZStack {
                // Карточки с свайпом на весь экран
                TabView(selection: $currentPage) {
                    ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                        VotingMovieCard(
                            movie: movie,
                            canVote: viewModel.canVote
                                && !(viewModel.votingProgress?.hasVoted ?? false),
                            movieId: movie.id,
                            onVote: { movieId in
                                Task {
                                    await viewModel.vote(movieCardId: movieId)
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                // Информация о раунде поверх карточки внизу в безопасной зоне
                VStack {
                    HStack {
                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Раунд \(viewModel.battle?.currentRound ?? 1)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            if let progress = viewModel.votingProgress {
                                Text(
                                    "Голосов: \(progress.totalVotes) / \(progress.totalParticipants)"
                                )
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            }

                            // Индикатор страниц
                            Text("\(currentPage + 1) / \(movies.count)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .cornerRadius(12)
                        .padding(.trailing)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)  // Отступ для безопасной зоны
            }
            .ignoresSafeArea()
        } else {
            VStack {
                Spacer()
                Text("Нет фильмов для голосования")
                    .foregroundColor(.secondary)
                    .font(.headline)
                Spacer()
            }
            .appBackground()
        }
    }
}

// MARK: - Voting Waiting View

struct VotingWaitingView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Заголовок
                VStack(spacing: 10) {
                    Text("Вы проголосовали")
                        .font(.title)
                        .bold()
                        .foregroundColor(.secondary)

                    if let progress = viewModel.votingProgress {
                        Text("Голосов: \(progress.totalVotes) / \(progress.totalParticipants)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // Если есть участники, которые еще не проголосовали
                if let progress = viewModel.votingProgress,
                    !progress.pendingParticipants.isEmpty
                {
                    VStack(alignment: .center, spacing: 15) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                            .symbolEffect(
                                .bounce.up.byLayer, options: .repeat(.periodic(delay: 0.5)))
                        Text("Ожидаем голосования от:")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(Array(progress.pendingParticipants.enumerated()), id: \.element.id)
                        { index, user in
                            HStack(spacing: 12) {
                                if let avatarUrl = user.avatarUrl,
                                    let url = URL(string: avatarUrl)
                                {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        SkeletonLoader()
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    SkeletonLoader()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name ?? user.username ?? "Неизвестный")
                                        .font(.headline)
                                    if let username = user.username {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                ProgressView()
                            }
                            .padding()
                            .background(Color("AccentColor").opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Если участник один или все проголосовали
                    VStack(spacing: 15) {
                        if let progress = viewModel.votingProgress,
                            progress.totalParticipants == 1
                        {
                            Image(systemName: "film.stack")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .symbolEffect(
                                    .bounce.up.byLayer, options: .repeat(.periodic(delay: 0.5)))
                            Text("Обработка результатов...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Вы единственный участник")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Все проголосовали!")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Обработка результатов...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color("AccentColor").opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .appBackground()
    }
}

// MARK: - Round Result Phase

struct RoundResultView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result = viewModel.roundResult {
                    // Заголовок
                    VStack {
                        Text("Раунд \(result.roundNumber) завершен")
                            .font(.title)
                            .bold()

                        Text("Выбыл фильм:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Выбывший фильм
                    VStack(spacing: 0) {
                        ZStack(alignment: .top) {
                            WinnerMovieCard(movie: result.eliminatedMovie, showOriginal: false)
                                .frame(height: 600)

                            VStack {
                                HStack {
                                    Text("❌")
                                        .font(.system(size: 40))
                                        .symbolEffect(.bounce, value: result.eliminatedMovie.id)

                                    Text("Выбыл фильм")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.top, 20)
                                Spacer()
                            }
                        }
                    }

                    // Результаты голосования
                    if !result.votes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Результаты голосования")
                                .font(.headline)
                                .padding(.horizontal)

                            // Группируем голоса по фильмам
                            let votesByMovie = Dictionary(grouping: result.votes) { $0.movieCardId }

                            ForEach(Array(votesByMovie.keys.sorted().enumerated()), id: \.element) {
                                index, movieId in
                                if let movie = viewModel.battle?.movies?.first(where: {
                                    $0.id == movieId
                                }),
                                    let votes = votesByMovie[movieId]
                                {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(movie.displayTitle)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text(
                                                "\(votes.count) голос\(votes.count == 1 ? "" : votes.count < 5 ? "а" : "ов")"
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }

                                        // Список проголосовавших
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(votes) { vote in
                                                HStack(spacing: 8) {
                                                    if let avatarUrl = vote.user?.avatarUrl,
                                                        let url = URL(string: avatarUrl)
                                                    {
                                                        AsyncImage(url: url) { image in
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            SkeletonLoader()
                                                        }
                                                        .frame(width: 24, height: 24)
                                                        .clipShape(Circle())
                                                    } else {
                                                        SkeletonLoader()
                                                            .frame(width: 24, height: 24)
                                                            .clipShape(Circle())
                                                    }

                                                    Text(
                                                        vote.user?.name ?? vote.user?.username
                                                            ?? "Неизвестный"
                                                    )
                                                    .font(.caption)

                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(
                                        movieId == result.eliminatedMovie.id
                                            ? Color.red.opacity(0.1) : Color.gray.opacity(0.05)
                                    )
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }

                    // Кнопка продолжения
                    Button(action: {
                        viewModel.continueToNextRound()
                    }) {
                        Text("Продолжить")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("AccentColor").opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .padding(.vertical)
        }
        .appBackground()
    }
}

// MARK: - Winner Phase

struct MovieBattleWinnerView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Заголовок
                VStack {
                    Text("🏆 Победитель!")
                        .font(.largeTitle)
                        .bold()
                }
                .padding()

                // Победитель
                if let winner = viewModel.winnerMovie {
                    VStack(spacing: 30) {
                        // Сгенерированный фильм-победитель
                        VStack(spacing: 0) {
                            ZStack(alignment: .top) {
                                WinnerMovieCard(movie: winner, showOriginal: false)
                                    .frame(height: 600)

                                VStack {
                                    Text("Фильм-победитель")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                            }
                        }

                        // Игрок, который добавил фильм
                        if let addedBy = winner.addedBy {
                            VStack(spacing: 10) {
                                HStack {
                                    if let avatarUrl = addedBy.avatarUrl,
                                        let url = URL(string: avatarUrl)
                                    {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            SkeletonLoader()
                                        }
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                    }

                                    VStack(alignment: .leading) {
                                        Text(addedBy.name ?? addedBy.username ?? "Неизвестный")
                                            .font(.headline)
                                        if let username = addedBy.username {
                                            Text("@\(username)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color("AccentColor").opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }

                        // Настоящий фильм-победитель
                        VStack(spacing: 0) {
                            ZStack(alignment: .top) {
                                WinnerMovieCard(movie: winner, showOriginal: true)
                                    .frame(height: 600)

                                VStack {
                                    Text("Настоящий фильм")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                            }
                        }
                    }
                } else {
                    // Если победитель не найден, показываем сообщение
                    VStack(spacing: 15) {
                        Text("Победитель не определен")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if let battle = viewModel.battle {
                            Text("Статус: \(battle.status.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let movies = battle.movies {
                                let remaining = movies.filter { !$0.isEliminated }
                                Text("Осталось фильмов: \(remaining.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if remaining.count == 1, let lastMovie = remaining.first {
                                    Text("Последний фильм: \(lastMovie.originalTitle)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Разделитель перед списком фильмов
                if let allMovies = viewModel.battle?.movies, !allMovies.isEmpty {
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }

                // Список всех фильмов
                if let allMovies = viewModel.battle?.movies, !allMovies.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Все фильмы")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)

                        ForEach(
                            allMovies.sorted(by: {
                                ($0.eliminatedAtRound ?? Int.max)
                                    < ($1.eliminatedAtRound ?? Int.max)
                            })
                        ) { movie in
                            VStack(alignment: .leading, spacing: 10) {
                                // Сгенерированный вариант
                                HStack {
                                    Text("🎬 Сгенерированный:")
                                        .font(.headline)
                                    Spacer()
                                }
                                MovieCardRow(
                                    movie: movie,
                                    showOriginalTitle: false,
                                    showGenerationStatus: false,
                                    showOriginalData: false
                                )

                                Divider()

                                // Оригинальный вариант
                                HStack {
                                    Text("📽️ Оригинальный:")
                                        .font(.headline)
                                    Spacer()
                                }
                                MovieCardRow(
                                    movie: movie,
                                    showOriginalTitle: true,
                                    showGenerationStatus: false,
                                    showOriginalData: true
                                )
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .appBackground()
    }
}

// MARK: - Supporting Views

struct MovieCardRow: View {
    @ObserveInjection var inject
    let movie: MovieCard
    let showOriginalTitle: Bool  // Показывать оригинальное название (для экрана сбора)
    let showGenerationStatus: Bool  // Показывать статус генерации
    let showOriginalData: Bool  // Показывать оригинальные постер и описание (для экрана сбора)

    init(
        movie: MovieCard, showOriginalTitle: Bool = false, showGenerationStatus: Bool = false,
        showOriginalData: Bool = false
    ) {
        self.movie = movie
        self.showOriginalTitle = showOriginalTitle
        self.showGenerationStatus = showGenerationStatus
        self.showOriginalData = showOriginalData
    }

    var body: some View {
        HStack {
            // Используем оригинальный постер, если showOriginalData = true, иначе displayPosterUrl
            let posterUrl = showOriginalData ? movie.originalPosterUrl : movie.displayPosterUrl
            if let posterUrl = posterUrl,
                let url = URL(string: posterUrl)
            {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(width: 50, height: 75)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(showOriginalTitle ? movie.originalTitle : movie.displayTitle)
                    .font(.headline)

                // Используем оригинальное описание, если showOriginalData = true, иначе displayDescription
                let description =
                    showOriginalData ? movie.originalDescription : movie.displayDescription
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Показываем статус генерации, если нужно
                if showGenerationStatus {
                    HStack(spacing: 4) {
                        switch movie.generationStatus {
                        case .pending, .generating, .titleReady, .posterReady, .descriptionReady:
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Генерируется...")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        case .completed:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("Готов")
                                .font(.caption2)
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Ошибка")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct VotingMovieCard: View {
    @ObserveInjection var inject
    let movie: MovieCard
    let canVote: Bool
    let movieId: String
    let onVote: (String) -> Void

    @State private var showFullDescription = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Размытый фон постера
                if let posterUrl = movie.displayPosterUrl,
                    let url = URL(string: posterUrl)
                {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        SkeletonLoader()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 20)  // Размытие фона
                    .overlay(
                        Color.black.opacity(0.3)  // Затемнение для лучшей читаемости
                    )
                } else {
                    // Плейсхолдер если нет постера
                    SkeletonLoader()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Четкий постер по центру
                VStack {
                    Spacer()

                    if let posterUrl = movie.displayPosterUrl,
                        let url = URL(string: posterUrl)
                    {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            SkeletonLoader()
                        }
                        .frame(maxWidth: 300, maxHeight: 450)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .padding(.bottom, 70)
                    }

                    Spacer()
                }

                // Контент внизу с размытием
                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        // Размытие под текстом
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.displayTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            if let description = movie.displayDescription {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .frame(
                                        maxHeight: showFullDescription ? nil : 60, alignment: .top
                                    )
                                    .clipped()
                                    .animation(
                                        .easeInOut(duration: 0.3), value: showFullDescription)

                                // Кнопка для показа/скрытия полного описания
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showFullDescription.toggle()
                                    }
                                }) {
                                    Text(showFullDescription ? "Свернуть" : "Показать полностью")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .underline()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                        // Кнопка
                        if canVote {
                            Button(action: {
                                onVote(movieId)
                            }) {
                                Text("Голосовать за выбывание")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color("AccentColor"))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 50)
                        }
                    }
                    .background(
                        .ultraThinMaterial
                    )
                    .cornerRadius(16)
                    // .padding(.bottom, 20)  // Отступ снизу, чтобы поднять контент выше
                    // .padding(.horizontal)
                }
            }
        }
        .ignoresSafeArea()
        .enableInjection()
    }
}

struct WinnerMovieCard: View {
    @ObserveInjection var inject
    let movie: MovieCard
    let showOriginal: Bool

    @State private var showFullDescription = false

    var posterUrl: String? {
        showOriginal ? movie.originalPosterUrl : movie.displayPosterUrl
    }

    var title: String {
        showOriginal ? movie.originalTitle : movie.displayTitle
    }

    var description: String? {
        showOriginal ? movie.originalDescription : movie.displayDescription
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Размытый фон постера
                if let posterUrl = posterUrl,
                    let url = URL(string: posterUrl)
                {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        SkeletonLoader()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 20)  // Размытие фона
                    .overlay(
                        Color.black.opacity(0.3)  // Затемнение для лучшей читаемости
                    )
                } else {
                    // Плейсхолдер если нет постера
                    SkeletonLoader()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }

                // Четкий постер по центру
                VStack {
                    Spacer()

                    if let posterUrl = posterUrl,
                        let url = URL(string: posterUrl)
                    {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            SkeletonLoader()
                        }
                        .frame(maxWidth: 300, maxHeight: 450)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .padding(.bottom, 70)
                    }

                    Spacer()
                }

                // Контент внизу с размытием
                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        // Размытие под текстом
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            if let description = description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .frame(
                                        maxHeight: showFullDescription ? nil : 60, alignment: .top
                                    )
                                    .clipped()
                                    .animation(
                                        .easeInOut(duration: 0.3), value: showFullDescription)

                                // Кнопка для показа/скрытия полного описания
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showFullDescription.toggle()
                                    }
                                }) {
                                    Text(showFullDescription ? "Свернуть" : "Показать полностью")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .underline()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .background(
                        .ultraThinMaterial
                    )
                    .cornerRadius(16)
                }
            }
        }
        .cornerRadius(16)
        .padding(.horizontal)
        .enableInjection()
    }
}

struct MovieCardDetail: View {
    @ObserveInjection var inject
    let movie: MovieCard
    let showOriginal: Bool

    var body: some View {
        VStack {
            if let posterUrl = showOriginal ? movie.originalPosterUrl : movie.displayPosterUrl,
                let url = URL(string: posterUrl)
            {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: 200)
                .cornerRadius(10)
            }

            Text(showOriginal ? movie.originalTitle : movie.displayTitle)
                .font(.title2)
                .bold()
                .padding(.top)

            if let description = showOriginal ? movie.originalDescription : movie.displayDescription
            {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

private enum BattleMovieSelectionMode: String, CaseIterable {
    case search = "Поиск"
    case myMovies = "Мои фильмы"
    case manual = "Ручной ввод"
}

struct AddMovieView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: MovieBattleViewModel
    @Environment(\.dismiss) var dismiss

    @StateObject private var kinopoiskService = KinopoiskService()
    @StateObject private var myMoviesService = MyMoviesService.shared

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var posterUrl: String = ""
    @State private var searchResults: [KinopoiskMovie] = []
    @State private var myMovies: [MyMovieListItem] = []
    @State private var selectedMovie: KinopoiskMovie?
    @State private var selectedMyMovie: MovieRecord?
    @State private var isLoading: Bool = false
    @State private var isLoadingMyMovies: Bool = false
    @State private var errorMessage: String?
    @State private var showingResults: Bool = false
    @State private var selectionMode: BattleMovieSelectionMode = .search
    @FocusState private var isFieldFocused: Bool

    @State private var searchDebouncer: Timer?
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelectingMovie: Bool = false  // Флаг для предотвращения поиска при выборе фильма
    @State private var isAddingMovie: Bool = false  // Флаг для отслеживания процесса добавления фильма

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Переключатель режима
                    Picker("Режим", selection: $selectionMode) {
                        ForEach(BattleMovieSelectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectionMode) { _, newMode in
                        if newMode == .myMovies {
                            loadMyMovies()
                        } else if newMode == .search {
                            cancelSearch()
                            showingResults = false
                        } else {
                            cancelSearch()
                            showingResults = false
                            selectedMovie = nil
                            selectedMyMovie = nil
                        }
                    }

                    if selectionMode == .search {
                        // Режим поиска через Kinopoisk
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Поиск фильма")
                                .font(.headline)
                                .padding(.horizontal)

                            TextField("Введите название фильма", text: $title)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isFieldFocused)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.thickMaterial)
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .keyboardType(.default)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.none)
                                .submitLabel(.search)
                                .onChange(of: title) { _, value in
                                    // Не запускаем поиск, если изменение происходит программно при выборе фильма
                                    guard !isSelectingMovie else {
                                        isSelectingMovie = false
                                        return
                                    }
                                    selectedMovie = nil
                                    description = ""
                                    posterUrl = ""
                                    debouncedSearch(query: value)
                                }

                            if isLoading {
                                ProgressView("Поиск фильмов...")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }

                            if showingResults && !searchResults.isEmpty {
                                LazyVStack(spacing: 12) {
                                    ForEach(searchResults, id: \.id) { movie in
                                        Button {
                                            selectMovie(movie)
                                        } label: {
                                            MovieSearchRow(
                                                movie: movie,
                                                isSelected: selectedMovie?.id == movie.id
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }

                            if let selectedMovie = selectedMovie {
                                SelectedMovieSummary(movie: selectedMovie)
                                    .padding(.horizontal)
                            }
                        }
                    } else if selectionMode == .myMovies {
                        // Режим выбора из моих фильмов
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Мои фильмы")
                                .font(.headline)
                                .padding(.horizontal)

                            if isLoadingMyMovies {
                                ProgressView("Загрузка...")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if myMovies.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "film")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("Нет сохраненных фильмов")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Добавьте фильмы в раздел 'Мои фильмы'")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(myMovies) { item in
                                            Button {
                                                selectMyMovie(item.movie)
                                            } label: {
                                                BattleMyMovieRow(
                                                    item: item,
                                                    isSelected: selectedMyMovie?.id == item.movie.id
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(maxHeight: 400)
                            }

                            if let selectedMyMovie = selectedMyMovie {
                                SelectedMyMovieSummary(movie: selectedMyMovie)
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        // Режим ручного ввода
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Информация о фильме")
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Название")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Название фильма", text: $title)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(.thickMaterial)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Описание (опционально)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Описание", text: $description, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(.thickMaterial)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("URL постера (опционально)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("URL", text: $posterUrl)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(.thickMaterial)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // Индикатор загрузки при добавлении фильма
                    if isAddingMovie {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.9)
                            Text("Добавление фильма...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor").opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        submit()
                    } label: {
                        if isAddingMovie {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Добавление...")
                            }
                        } else {
                            Text("Добавить")
                        }
                    }
                    .disabled(title.isEmpty || isAddingMovie)
                }
            }
            .appBackground()
        }
        .onDisappear {
            cancelSearch()
        }
    }

    // MARK: - Private Methods

    private func debouncedSearch(query: String) {
        searchDebouncer?.invalidate()
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchResults = []
            showingResults = false
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
        guard query.count >= 2 else {
            searchResults = []
            showingResults = false
            return
        }

        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                let results = try await kinopoiskService.searchMovies(query: query)
                if Task.isCancelled { return }
                await MainActor.run {
                    searchResults = results
                    showingResults = true
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

    private func selectMovie(_ movie: KinopoiskMovie) {
        isSelectingMovie = true  // Устанавливаем флаг перед изменением title
        selectedMovie = movie
        selectedMyMovie = nil
        title = movie.name
        description = movie.description ?? movie.shortDescription ?? ""
        posterUrl = movie.poster?.bestUrl ?? ""
        showingResults = false
        cancelSearch()
    }

    private func loadMyMovies() {
        guard !isLoadingMyMovies else { return }
        isLoadingMyMovies = true

        Task {
            do {
                let response = try await myMoviesService.myMovies(page: 1, limit: 50)
                await MainActor.run {
                    myMovies = response.items
                    isLoadingMyMovies = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка загрузки фильмов: \(error.localizedDescription)"
                    isLoadingMyMovies = false
                }
            }
        }
    }

    private func selectMyMovie(_ movie: MovieRecord) {
        selectedMyMovie = movie
        selectedMovie = nil
        title = movie.name ?? ""
        description = movie.description ?? movie.shortDescription ?? ""
        posterUrl = movie.posterUrl ?? movie.posterPreviewUrl ?? ""
    }

    private func submit() {
        guard let battleId = viewModel.battle?.id else { return }

        // Предотвращаем повторные нажатия
        guard !isAddingMovie else { return }

        // Определяем kinopoiskId в зависимости от выбранного режима
        let kinopoiskId: String?
        if let myMovie = selectedMyMovie {
            kinopoiskId = myMovie.kpId
        } else if let searchMovie = selectedMovie {
            kinopoiskId = String(searchMovie.id)
        } else {
            kinopoiskId = nil
        }

        let request = AddMovieRequest(
            battleId: battleId,
            kinopoiskId: kinopoiskId,
            title: title,
            description: description.isEmpty ? nil : description,
            posterUrl: posterUrl.isEmpty ? nil : posterUrl
        )

        Task {
            await MainActor.run {
                isAddingMovie = true
                errorMessage = nil
            }

            await viewModel.addMovie(request: request)

            await MainActor.run {
                isAddingMovie = false
                if viewModel.errorMessage == nil {
                    dismiss()
                } else {
                    // Показываем ошибку из viewModel в локальном errorMessage
                    errorMessage = viewModel.errorMessage
                }
            }
        }
    }
}

// MARK: - Movie Search Components

private struct MovieSearchRow: View {
    @ObserveInjection var inject
    let movie: KinopoiskMovie
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let url = movie.poster?.bestUrl.flatMap(URL.init) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                ZStack {
                    SkeletonLoader()
                    Image(systemName: "film")
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name)
                    .font(.headline)
                    .lineLimit(2)

                Text("\(movie.year)")
                    .font(.caption)
                    .foregroundColor(.secondary)

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
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name)
                    .font(.headline)
                Text("\(movie.year)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

// MARK: - My Movies Components

private struct BattleMyMovieRow: View {
    @ObserveInjection var inject
    let item: MyMovieListItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = item.movie.posterPreviewUrl ?? item.movie.posterUrl,
                let url = URL(string: urlString)
            {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            } else {
                ZStack {
                    SkeletonLoader()
                    Image(systemName: "film")
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.movie.name ?? "Без названия")
                    .font(.headline)
                    .lineLimit(2)

                if let year = item.movie.year {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let genre = item.movie.genres?.first?.name {
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

private struct SelectedMyMovieSummary: View {
    @ObserveInjection var inject
    let movie: MovieRecord

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = movie.posterPreviewUrl ?? movie.posterUrl,
                let url = URL(string: urlString)
            {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    SkeletonLoader()
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.name ?? "Без названия")
                    .font(.headline)
                if let year = movie.year {
                    Text("\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let desc = movie.shortDescription ?? movie.description, !desc.isEmpty {
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

// MARK: - Extensions
