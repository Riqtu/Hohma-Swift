//
//  MovieBattleViewModel.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import SwiftUI

@MainActor
class MovieBattleViewModel: ObservableObject, TRPCServiceProtocol {
    @Published var battle: MovieBattle?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Состояние игры
    @Published var currentPhase: GamePhase = .collecting
    @Published var generationProgress: [String: GenerationProgress] = [:]  // movieCardId -> progress
    @Published var votingProgress: VotingProgress?
    @Published var roundResult: RoundResult?  // Результаты текущего раунда

    // UI состояния
    @Published var showingAddMovieSheet: Bool = false
    @Published var showingResults: Bool = false

    private let service = MovieBattleService.shared
    private var socketManager: MovieBattleSocketManager?
    private var battleId: String?

    enum GamePhase {
        case collecting
        case generating
        case voting
        case roundResult  // Промежуточный экран результатов раунда
        case finished
    }

    struct GenerationProgress {
        let status: GenerationStatus
        let progress: Double  // 0.0 - 1.0
    }

    struct VotingProgress {
        let roundNumber: Int
        let totalVotes: Int
        let totalParticipants: Int
        let hasVoted: Bool
        let pendingParticipants: [MovieBattleUser]  // Кто еще не проголосовал
    }

    struct RoundResult {
        let roundNumber: Int
        let eliminatedMovie: MovieCard
        let isFinished: Bool  // true если это финальный результат (победитель определен)
        let votes: [Vote]  // Голоса за этот раунд
    }

    // MARK: - Initialization

    func loadBattle(id: String) async {
        battleId = id
        isLoading = true
        errorMessage = nil

        do {
            var loadedBattle = try await service.getBattleById(
                id: id,
                includeMovies: true,
                includeParticipants: true,
                includeVotes: false
            )

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            // Проверяем, является ли пользователь участником
            // (автоматическое присоединение убрано - теперь пользователь должен нажать кнопку)

            await MainActor.run {
                // Фильтруем фильмы сразу при загрузке битвы
                let filteredBattle = self.filterMovies(loadedBattle)

                // Защита: если текущая игра уже завершена с победителем,
                // не перезаписываем состояние, если загруженные данные не содержат завершенную игру с победителем
                if let currentBattle = self.battle,
                    currentBattle.status == .finished,
                    let currentWinner = self.winnerMovie
                {
                    // Проверяем, есть ли победитель в загруженных данных И статус FINISHED
                    let hasWinnerInLoaded =
                        filteredBattle.status == .finished
                        && {
                            if filteredBattle.movies?.first(where: { $0.finalPosition == 1 }) != nil
                            {
                                return true
                            }
                            if let remaining = filteredBattle.movies?.filter({ !$0.isEliminated }),
                                remaining.count == 1
                            {
                                return true
                            }
                            return false
                        }()

                    if !hasWinnerInLoaded {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Loaded battle doesn't contain finished game with winner, keeping current state", category: .ui)
                        AppLogger.shared.debug(
                            "   Current winner: \(currentWinner.originalTitle), finalPosition: \(currentWinner.finalPosition ?? -1)", category: .ui)
                        AppLogger.shared.debug(
                            "   Loaded status: \(filteredBattle.status), movies count: \(filteredBattle.movies?.count ?? 0)", category: .ui)
                        // Не перезаписываем состояние, но обновляем другие поля если нужно
                        self.isLoading = false
                        return
                    }

                    // Если загруженные данные содержат победителя, обновляем состояние
                    if hasWinnerInLoaded {
                        if let loadedWinner = filteredBattle.movies?.first(where: {
                            $0.finalPosition == 1
                        }),
                            loadedWinner.id != currentWinner.id
                        {
                            AppLogger.shared.warning(
                                "MovieBattleViewModel: Loaded battle has different winner, updating state", category: .ui)
                            AppLogger.shared.debug(
                                "   Current winner: \(currentWinner.originalTitle), Loaded winner: \(loadedWinner.originalTitle)", category: .ui)
                        } else {
                            AppLogger.shared.debug(
                                "MovieBattleViewModel: Loaded battle has same winner or winner confirmed, updating state", category: .ui)
                        }
                    }
                }

                self.battle = filteredBattle

                // Если игра завершена, проверяем наличие победителя
                if filteredBattle.status == .finished {
                    AppLogger.shared.debug("Loaded finished battle, checking winner", category: .ui)
                    AppLogger.shared.debug(
                        "   Battle status: \(filteredBattle.status), movies count: \(filteredBattle.movies?.count ?? 0)", category: .ui)

                    // Проверяем победителя напрямую в filteredBattle
                    let winner: MovieCard? = {
                        // Сначала ищем по finalPosition
                        if let winner = filteredBattle.movies?.first(where: {
                            $0.finalPosition == 1
                        }) {
                            AppLogger.shared.debug(
                                "MovieBattleViewModel: Winner found by finalPosition: \(winner.originalTitle)", category: .ui)
                            return winner
                        }
                        // Если игра завершена и остался только один не выбывший фильм - он победитель
                        if let remainingMovies = filteredBattle.movies?.filter({ !$0.isEliminated }
                        ),
                            remainingMovies.count == 1
                        {
                            AppLogger.shared.debug(
                                "MovieBattleViewModel: Winner found by remaining: \(remainingMovies.first?.originalTitle ?? "unknown")", category: .ui)
                            return remainingMovies.first
                        }
                        return nil
                    }()

                    if let winner = winner {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Winner confirmed after load: \(winner.originalTitle), finalPosition: \(winner.finalPosition ?? -1)", category: .ui)
                    } else {
                        AppLogger.shared.warning("Winner not found after load", category: .ui)
                        if let movies = filteredBattle.movies {
                            AppLogger.shared.debug("All movies:", category: .ui)
                            for movie in movies {
                                AppLogger.shared.debug(
                                    "     - \(movie.originalTitle): finalPosition=\(movie.finalPosition ?? -1), eliminatedAtRound=\(movie.eliminatedAtRound ?? -1)", category: .ui)
                            }
                        }
                    }
                }

                self.updatePhase()
                self.setupSocket()
                self.isLoading = false
            }
        } catch {
            // Игнорируем ошибки отмены запроса (это нормально при навигации)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }

            // Проверяем, не была ли задача отменена
            if Task.isCancelled { return }

            await MainActor.run {
                self.errorMessage = "Ошибка загрузки игры: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Actions

    func createBattle(request: CreateMovieBattleRequest) async {
        isLoading = true
        errorMessage = nil

        do {
            let createdBattle = try await service.createBattle(request)

            if Task.isCancelled { return }

            await MainActor.run {
                self.battle = createdBattle
                self.battleId = createdBattle.id
                self.updatePhase()
                self.setupSocket()
                self.isLoading = false
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return
            }
            if Task.isCancelled { return }

            await MainActor.run {
                self.errorMessage = "Ошибка создания игры: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func joinBattle() async {
        guard let battleId = battleId else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedBattle = try await service.joinBattle(battleId: battleId)

            await MainActor.run {
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(updatedBattle)
                self.battle = filteredBattle
                self.updatePhase()
                self.setupSocket()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка присоединения: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func addMovie(request: AddMovieRequest) async {
        isLoading = true
        errorMessage = nil

        do {
            let updatedBattle = try await service.addMovie(request)

            await MainActor.run {
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(updatedBattle)
                self.battle = filteredBattle
                self.updatePhase()
                self.showingAddMovieSheet = false
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка добавления фильма: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func startBattle() async {
        guard let battleId = battleId else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedBattle = try await service.startBattle(battleId: battleId)

            await MainActor.run {
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(updatedBattle)
                self.battle = filteredBattle
                self.updatePhase()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка запуска игры: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func vote(movieCardId: String) async {
        guard let battleId = battleId else { return }

        isLoading = true
        errorMessage = nil

        do {
            let request = VoteRequest(battleId: battleId, movieCardId: movieCardId)
            let updatedBattle = try await service.vote(request)

            await MainActor.run {
                // Фильтруем фильмы перед обновлением состояния (для статусов CREATED/COLLECTING)
                let filteredBattle = self.filterMovies(updatedBattle)

                // Защита: если игра уже завершена с победителем, не перезаписываем состояние
                // Ответ от vote может содержать старые данные (status = VOTING), так как
                // раунд завершается асинхронно после возврата ответа
                if let currentBattle = self.battle,
                    currentBattle.status == .finished,
                    self.winnerMovie != nil
                {
                    let hasFinishedGameWithWinner =
                        filteredBattle.status == .finished
                        && {
                            if filteredBattle.movies?.first(where: { $0.finalPosition == 1 }) != nil
                            {
                                return true
                            }
                            if let remaining = filteredBattle.movies?.filter({ !$0.isEliminated }),
                                remaining.count == 1
                            {
                                return true
                            }
                            return false
                        }()

                    if !hasFinishedGameWithWinner {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Vote response doesn't contain finished game with winner, keeping current state", category: .ui)
                        AppLogger.shared.debug(
                            "   Current status: \(currentBattle.status), Response status: \(filteredBattle.status)", category: .ui)
                        self.isLoading = false
                        return
                    }
                }

                self.battle = filteredBattle
                self.updateVotingProgress()
                self.isLoading = false
                // После голосования обновляем фазу, но не переключаем на результаты раунда
                // Результаты раунда будут показаны через socket событие round:complete
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка голосования: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func deleteBattle() async {
        guard let battleId = battleId else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await service.deleteBattle(battleId: battleId)

            await MainActor.run {
                self.battle = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Ошибка удаления игры: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Computed Properties

    var canAddMovie: Bool {
        guard let battle = battle else { return false }
        return battle.status == .created || battle.status == .collecting
    }

    var canStartBattle: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }

        // Используем общее количество фильмов из _count, если доступно
        // Иначе используем количество из массива movies (для создателя это все фильмы)
        let movieCount = battle._count?.movies ?? battle.movies?.count ?? 0

        return battle.creator.id == currentUserId
            && movieCount >= battle.minMovies
            && (battle.status == .created || battle.status == .collecting)
    }

    var isCreator: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }
        return battle.creator.id == currentUserId
    }

    var isParticipant: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }
        return battle.participants?.contains { $0.userId == currentUserId } ?? false
    }

    var canJoinBattle: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }
        
        // Проверяем, является ли пользователь уже участником
        let isParticipant = battle.participants?.contains { $0.userId == currentUserId } ?? false
        if isParticipant { return false }
        
        // Можно присоединиться только если игра еще не началась
        return (battle.status == .created || battle.status == .collecting)
    }

    var canDeleteBattle: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }
        // Можно удалять только свои батлы на любом этапе (любой статус)
        return battle.creator.id == currentUserId
    }

    var canVote: Bool {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else { return false }

        if battle.status != .voting { return false }

        // Проверяем, является ли пользователь участником
        let isParticipant = battle.participants?.contains { $0.userId == currentUserId } ?? false
        if !isParticipant { return false }

        // Проверяем, не голосовал ли уже
        if let votes = battle.votes {
            let currentRoundVotes = votes.filter { $0.roundNumber == battle.currentRound }
            return !currentRoundVotes.contains { $0.userId == currentUserId }
        }

        return true
    }

    var remainingMovies: [MovieCard] {
        battle?.movies?.filter { !$0.isEliminated } ?? []
    }

    var eliminatedMovies: [MovieCard] {
        battle?.movies?.filter { $0.isEliminated } ?? []
    }

    var winnerMovie: MovieCard? {
        guard let battle = battle, battle.status == .finished else {
            return nil
        }

        // Сначала ищем по finalPosition
        if let winner = battle.movies?.first(where: { $0.isWinner }) {
            AppLogger.shared.info("Found by finalPosition = 1", category: .ui)
            return winner
        }

        // Если игра завершена и остался только один не выбывший фильм - он победитель
        if let remainingMovies = battle.movies?.filter({ !$0.isEliminated }),
            remainingMovies.count == 1
        {
            AppLogger.shared.info("Found by remaining movies (count = 1)", category: .ui)
            return remainingMovies.first
        }

        // Fallback: ищем фильм с finalPosition == 1 напрямую
        if let winner = battle.movies?.first(where: { $0.finalPosition == 1 }) {
            AppLogger.shared.info("Found by finalPosition == 1 (direct check)", category: .ui)
            return winner
        }

        AppLogger.shared.warning(
            "WinnerMovie: No winner found. Status: \(battle.status), Movies count: \(battle.movies?.count ?? 0)", category: .ui)
        if let movies = battle.movies {
            for movie in movies {
                AppLogger.shared.debug(
                    "   Movie: \(movie.originalTitle), finalPosition: \(movie.finalPosition ?? -1), eliminatedAtRound: \(movie.eliminatedAtRound ?? -1)", category: .ui)
            }
        }

        return nil
    }

    // MARK: - Private Methods

    /// Фильтрует фильмы в зависимости от статуса игры и текущего пользователя
    /// До начала генерации (CREATED, COLLECTING) показываем только свои фильмы
    /// После начала генерации показываем все фильмы
    private func filterMovies(_ battle: MovieBattle) -> MovieBattle {
        guard let currentUserId = trpcService.currentUser?.id,
            let movies = battle.movies
        else {
            return battle
        }

        // Если игра еще не началась (CREATED или COLLECTING), фильтруем фильмы
        if battle.status == .created || battle.status == .collecting {
            let filteredMovies = movies.filter { movie in
                movie.addedBy?.id == currentUserId
            }

            // Создаем новый объект battle с отфильтрованными фильмами через JSON
            do {
                let encoder = JSONEncoder()
                var battleDict =
                    try JSONSerialization.jsonObject(with: encoder.encode(battle)) as? [String: Any]
                    ?? [:]

                var moviesArray: [[String: Any]] = []
                for movie in filteredMovies {
                    if let movieData = try? encoder.encode(movie),
                        let movieDict = try? JSONSerialization.jsonObject(with: movieData)
                            as? [String: Any]
                    {
                        moviesArray.append(movieDict)
                    }
                }
                battleDict["movies"] = moviesArray

                let decoder = JSONDecoder()
                if let battleData = try? JSONSerialization.data(withJSONObject: battleDict),
                    let filtered = try? decoder.decode(MovieBattle.self, from: battleData)
                {
                    return filtered
                }
            } catch {
                AppLogger.shared.warning("Failed to filter movies: \(error)", category: .ui)
            }
        }

        // После начала генерации показываем все фильмы
        return battle
    }

    private func updatePhase() {
        guard let battle = battle else { return }

        // Если есть результаты раунда и игра еще не завершена, не переключаем фазу автоматически
        if let result = roundResult, !result.isFinished && battle.status == .voting {
            // Остаемся на экране результатов раунда
            return
        }

        // Если игра завершена, очищаем результаты раунда и переходим к победителю
        if battle.status == .finished {
            roundResult = nil
            currentPhase = .finished
            showingResults = true
            return
        }

        switch battle.status {
        case .created, .collecting:
            currentPhase = .collecting
            roundResult = nil
        case .generating:
            currentPhase = .generating
            roundResult = nil
        case .voting:
            // Если нет результатов раунда, показываем голосование
            if roundResult == nil {
                currentPhase = .voting
                updateVotingProgress()
            }
        case .finished:
            currentPhase = .finished
            showingResults = true
            roundResult = nil
        case .cancelled:
            currentPhase = .finished
            roundResult = nil
        }
    }

    // Переход к следующему раунду голосования
    func continueToNextRound() {
        roundResult = nil
        // Перезагружаем битву, чтобы получить актуальное состояние
        if let battleId = battleId {
            Task {
                await loadBattle(id: battleId)
            }
        } else {
            updatePhase()
        }
    }

    private func updateVotingProgress() {
        guard let battle = battle,
            let currentUserId = trpcService.currentUser?.id
        else {
            votingProgress = nil
            return
        }

        let totalParticipants = battle.participants?.count ?? 0
        let currentRoundVotes = battle.votes?.filter { $0.roundNumber == battle.currentRound } ?? []
        let hasVoted = currentRoundVotes.contains { $0.userId == currentUserId }

        // Определяем, кто еще не проголосовал
        let votedUserIds = Set(currentRoundVotes.map { $0.userId })
        let pendingParticipants =
            battle.participants?.compactMap { participant -> MovieBattleUser? in
                // Пропускаем текущего пользователя, если он уже проголосовал
                if participant.userId == currentUserId && hasVoted {
                    return nil
                }
                // Если участник еще не проголосовал, добавляем его в список ожидания
                if !votedUserIds.contains(participant.userId) {
                    return participant.user
                }
                return nil
            } ?? []

        votingProgress = VotingProgress(
            roundNumber: battle.currentRound,
            totalVotes: currentRoundVotes.count,
            totalParticipants: totalParticipants,
            hasVoted: hasVoted,
            pendingParticipants: pendingParticipants
        )
    }

    private func setupSocket() {
        guard let battleId = battleId,
            let userId = trpcService.currentUser?.id
        else { return }

        // Отключаем старый сокет, если он есть
        if let existingManager = socketManager {
            AppLogger.shared.debug("Disconnecting old socket manager", category: .ui)
            existingManager.disconnect()
        }

        AppLogger.shared.debug("Setting up socket for battle \(battleId)", category: .ui)
        let socketAdapter = SocketIOServiceAdapter()
        socketManager = MovieBattleSocketManager(
            socket: socketAdapter, battleId: battleId, userId: userId)

        socketManager?.onBattleUpdate = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                AppLogger.shared.debug("Received battle update via socket", category: .ui)

                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(battle)

                // Защита: если игра уже завершена и есть победитель, проверяем новое обновление
                // Не перезаписываем данные, если в новом обновлении нет завершенной игры с победителем
                // Проверяем победителя в текущем состоянии напрямую
                let currentWinner: MovieCard? = {
                    guard let currentBattle = self.battle,
                        currentBattle.status == .finished
                    else { return nil }
                    // Ищем по finalPosition
                    if let winner = currentBattle.movies?.first(where: { $0.finalPosition == 1 }) {
                        return winner
                    }
                    // Ищем по единственному не выбывшему фильму
                    if let remaining = currentBattle.movies?.filter({ !$0.isEliminated }),
                        remaining.count == 1
                    {
                        return remaining.first
                    }
                    return nil
                }()

                if let currentWinner = currentWinner {
                    AppLogger.shared.debug(
                        "MovieBattleViewModel: Battle already finished with winner: \(currentWinner.originalTitle)", category: .ui)

                    // Проверяем, есть ли завершенная игра с победителем в новом обновлении
                    // Важно: проверяем не только наличие победителя, но и статус FINISHED
                    let hasFinishedGameWithWinner =
                        filteredBattle.status == .finished
                        && {
                            // Проверяем по finalPosition
                            if let winner = filteredBattle.movies?.first(where: {
                                $0.finalPosition == 1
                            }) {
                                AppLogger.shared.debug(
                                    "MovieBattleViewModel: Winner found in new update by finalPosition: \(winner.originalTitle)", category: .ui)
                                return true
                            }
                            // Проверяем по единственному не выбывшему фильму
                            if let remaining = filteredBattle.movies?.filter({ !$0.isEliminated }),
                                remaining.count == 1,
                                let winner = remaining.first
                            {
                                AppLogger.shared.debug(
                                    "MovieBattleViewModel: Winner found in new update by remaining: \(winner.originalTitle)", category: .ui)
                                return true
                            }
                            AppLogger.shared.warning("No winner found in new update", category: .ui)
                            return false
                        }()

                    if !hasFinishedGameWithWinner {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Ignoring battle update - new update doesn't contain finished game with winner, keeping current state", category: .ui)
                        AppLogger.shared.debug(
                            "   Current winner: \(currentWinner.originalTitle), finalPosition: \(currentWinner.finalPosition ?? -1)", category: .ui)
                        AppLogger.shared.debug(
                            "   New update status: \(filteredBattle.status)", category: .ui)
                        if let newMovies = filteredBattle.movies {
                            AppLogger.shared.debug("New update movies count: \(newMovies.count)", category: .ui)
                            for movie in newMovies {
                                AppLogger.shared.debug(
                                    "     - \(movie.originalTitle): finalPosition=\(movie.finalPosition ?? -1), eliminatedAtRound=\(movie.eliminatedAtRound ?? -1)", category: .ui)
                            }
                        }
                        return
                    }

                    AppLogger.shared.debug(
                        "MovieBattleViewModel: New update contains finished game with winner, updating state", category: .ui)
                }

                // Обновляем состояние
                self.battle = filteredBattle

                // Если игра только что завершилась или была завершена, убеждаемся что показываем победителя
                if filteredBattle.status == .finished {
                    AppLogger.shared.debug("🏆 MovieBattleViewModel: Battle finished, checking winner", category: .ui)
                    if let winner = self.winnerMovie {
                        AppLogger.shared.info("Winner found: \(winner.originalTitle)", category: .ui)
                    } else {
                        AppLogger.shared.warning(
                            "MovieBattleViewModel: Winner not found yet, will refresh battle data", category: .ui)
                        // Если победитель не найден, запрашиваем обновленные данные с сервера
                        Task {
                            await self.loadBattle(id: filteredBattle.id)
                        }
                    }
                }

                self.updatePhase()

                // Обновляем прогресс генерации для всех фильмов (используем отфильтрованные)
                if let movies = filteredBattle.movies {
                    AppLogger.shared.debug(
                        "MovieBattleViewModel: Updating generation progress for \(movies.count) movies", category: .ui)
                    for movie in movies {
                        let status = movie.generationStatus
                        let progress: Double
                        switch status {
                        case .pending:
                            progress = 0.0
                        case .generating:
                            progress = 0.2
                        case .titleReady:
                            progress = 0.4
                        case .posterReady:
                            progress = 0.6
                        case .descriptionReady:
                            progress = 0.8
                        case .completed:
                            progress = 1.0
                        case .failed:
                            progress = 0.0
                        }
                        self.generationProgress[movie.id] = GenerationProgress(
                            status: status,
                            progress: progress
                        )
                    }
                    AppLogger.shared.info("Generation progress updated, UI should refresh", category: .ui)
                }
            }
        }

        socketManager?.onMovieAdded = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(battle)
                self.battle = filteredBattle
                self.updatePhase()
            }
        }

        socketManager?.onGenerationStarted = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(battle)
                self.battle = filteredBattle
                self.updatePhase()
                // Инициализируем прогресс для всех фильмов (используем отфильтрованные)
                if let movies = filteredBattle.movies {
                    for movie in movies {
                        let status = movie.generationStatus
                        let progress: Double
                        switch status {
                        case .pending:
                            progress = 0.0
                        case .generating:
                            progress = 0.2
                        case .titleReady:
                            progress = 0.4
                        case .posterReady:
                            progress = 0.6
                        case .descriptionReady:
                            progress = 0.8
                        case .completed:
                            progress = 1.0
                        case .failed:
                            progress = 0.0
                        }
                        self.generationProgress[movie.id] = GenerationProgress(
                            status: status,
                            progress: progress
                        )
                    }
                }
            }
        }

        socketManager?.onGenerationProgress = { [weak self] movieCardId, status, movieCard in
            Task { @MainActor in
                guard let self = self else { return }

                AppLogger.shared.debug(
                    "MovieBattleViewModel: Received generation progress - movieCardId: \(movieCardId), status: \(status.rawValue)", category: .socket)

                // Определяем прогресс в зависимости от статуса
                let progress: Double
                switch status {
                case .pending:
                    progress = 0.0
                case .generating:
                    progress = 0.2
                case .titleReady:
                    progress = 0.4
                case .posterReady:
                    progress = 0.6
                case .descriptionReady:
                    progress = 0.8
                case .completed:
                    progress = 1.0
                case .failed:
                    progress = 0.0
                }

                // Обновляем прогресс генерации немедленно для мгновенного отображения
                self.generationProgress[movieCardId] = GenerationProgress(
                    status: status,
                    progress: progress
                )
                AppLogger.shared.info("Updated generationProgress for \(movieCardId)", category: .ui)

                // Перезагружаем игру для синхронизации
                // Это гарантирует, что все данные актуальны и UI обновится
                // НО: не перезагружаем, если игра уже завершена с победителем
                if let battleId = self.battleId {
                    // Проверяем, не завершена ли игра уже
                    let isFinished = self.battle?.status == .finished && self.winnerMovie != nil

                    if isFinished {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Game already finished with winner, skipping reload to preserve state", category: .ui)
                        return
                    }

                    AppLogger.shared.debug("Reloading battle from API...", category: .ui)
                    do {
                        let updatedBattle = try await self.service.getBattleById(
                            id: battleId,
                            includeMovies: true,
                            includeParticipants: true,
                            includeVotes: false
                        )

                        AppLogger.shared.info("Battle reloaded, updating UI", category: .ui)

                        // Фильтруем фильмы перед обновлением состояния
                        let filteredBattle = self.filterMovies(updatedBattle)

                        // Дополнительная защита: если игра уже завершена с победителем, не перезаписываем
                        if let currentBattle = self.battle,
                            currentBattle.status == .finished,
                            self.winnerMovie != nil
                        {
                            let hasFinishedGameWithWinner =
                                filteredBattle.status == .finished
                                && {
                                    if filteredBattle.movies?.first(where: { $0.finalPosition == 1 }
                                    ) != nil {
                                        return true
                                    }
                                    if let remaining = filteredBattle.movies?.filter({
                                        !$0.isEliminated
                                    }),
                                        remaining.count == 1
                                    {
                                        return true
                                    }
                                    return false
                                }()

                            if !hasFinishedGameWithWinner {
                                AppLogger.shared.debug(
                                    "MovieBattleViewModel: Reloaded battle doesn't contain finished game with winner, keeping current state", category: .ui)
                                return
                            }
                        }

                        // Обновляем battle - это вызовет обновление UI через @Published
                        self.battle = filteredBattle

                        // Обновляем прогресс генерации для всех фильмов после обновления battle (используем отфильтрованные)
                        if let movies = filteredBattle.movies {
                            for movie in movies {
                                let movieStatus = movie.generationStatus
                                let movieProgress: Double
                                switch movieStatus {
                                case .pending:
                                    movieProgress = 0.0
                                case .generating:
                                    movieProgress = 0.2
                                case .titleReady:
                                    movieProgress = 0.4
                                case .posterReady:
                                    movieProgress = 0.6
                                case .descriptionReady:
                                    movieProgress = 0.8
                                case .completed:
                                    movieProgress = 1.0
                                case .failed:
                                    movieProgress = 0.0
                                }
                                self.generationProgress[movie.id] = GenerationProgress(
                                    status: movieStatus,
                                    progress: movieProgress
                                )
                            }
                        }

                        AppLogger.shared.info("UI should be updated now", category: .ui)
                    } catch {
                        AppLogger.shared.warning("Ошибка обновления фильма: \(error.localizedDescription)", category: .ui)
                    }
                }
            }
        }

        socketManager?.onVotingStarted = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(battle)
                self.battle = filteredBattle
                self.updatePhase()
            }
        }

        socketManager?.onVoteCast = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                // Фильтруем фильмы перед обновлением состояния
                let filteredBattle = self.filterMovies(battle)
                self.battle = filteredBattle
                self.updateVotingProgress()
            }
        }

        socketManager?.onRoundComplete = {
            [weak self] battle, eliminatedMovieId, roundNumber, isFinished in
            Task { @MainActor in
                guard let self = self else { return }
                AppLogger.shared.debug(
                    "MovieBattleViewModel: Received round complete event - roundNumber: \(roundNumber), eliminatedMovieId: \(eliminatedMovieId), isFinished: \(isFinished)", category: .socket)

                // Проверяем, не является ли это событие для уже завершенного раунда
                // Если текущий раунд битвы уже больше, чем roundNumber из события, игнорируем его
                if let currentBattle = self.battle,
                    currentBattle.currentRound > roundNumber
                {
                    AppLogger.shared.warning(
                        "MovieBattleViewModel: Ignoring round complete event for round \(roundNumber) - current round is \(currentBattle.currentRound)", category: .socket)
                    return
                }

                // Фильтруем фильмы перед обновлением состояния (для статусов CREATED/COLLECTING)
                let filteredBattle = self.filterMovies(battle)

                // Защита: если игра уже завершена и есть победитель, проверяем новое обновление
                // Проверяем победителя в текущем состоянии напрямую
                let currentWinner: MovieCard? = {
                    guard let currentBattle = self.battle,
                        currentBattle.status == .finished
                    else { return nil }
                    // Ищем по finalPosition
                    if let winner = currentBattle.movies?.first(where: { $0.finalPosition == 1 }) {
                        return winner
                    }
                    // Ищем по единственному не выбывшему фильму
                    if let remaining = currentBattle.movies?.filter({ !$0.isEliminated }),
                        remaining.count == 1
                    {
                        return remaining.first
                    }
                    return nil
                }()

                let shouldUpdateBattle: Bool
                if let currentWinner = currentWinner {
                    // Проверяем, есть ли завершенная игра с победителем в новом обновлении
                    // Важно: проверяем не только наличие победителя, но и статус FINISHED
                    let hasFinishedGameWithWinner =
                        filteredBattle.status == .finished
                        && {
                            if filteredBattle.movies?.first(where: { $0.finalPosition == 1 }) != nil
                            {
                                return true
                            }
                            if let remaining = filteredBattle.movies?.filter({ !$0.isEliminated }),
                                remaining.count == 1
                            {
                                return true
                            }
                            return false
                        }()

                    if !hasFinishedGameWithWinner {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Round complete - new update doesn't contain finished game with winner, keeping current battle state", category: .ui)
                        AppLogger.shared.debug("Current winner: \(currentWinner.originalTitle)", category: .ui)
                        AppLogger.shared.debug("New update status: \(filteredBattle.status)", category: .ui)
                        shouldUpdateBattle = false
                    } else {
                        AppLogger.shared.debug(
                            "MovieBattleViewModel: Round complete - new update contains finished game with winner, updating battle state", category: .ui)
                        shouldUpdateBattle = true
                    }
                } else {
                    // Обновляем состояние
                    shouldUpdateBattle = true
                }

                // Обновляем состояние только если нужно
                if shouldUpdateBattle {
                    self.battle = filteredBattle
                }

                // Находим выбывший фильм
                if let eliminatedMovie = battle.movies?.first(where: { $0.id == eliminatedMovieId })
                {
                    AppLogger.shared.debug(
                        "MovieBattleViewModel: Found eliminated movie: \(eliminatedMovie.originalTitle)", category: .ui)

                    // Получаем голоса за этот раунд
                    let roundVotes = battle.votes?.filter { $0.roundNumber == roundNumber } ?? []

                    // Устанавливаем результаты раунда только если это актуальный раунд
                    let currentRound = battle.currentRound
                    // Если это событие для текущего или предыдущего раунда, показываем результаты
                    // (roundNumber может быть меньше currentRound на 1, если это событие для только что завершенного раунда)
                    if roundNumber >= currentRound - 1 {
                        self.roundResult = RoundResult(
                            roundNumber: roundNumber,  // Используем roundNumber из события
                            eliminatedMovie: eliminatedMovie,
                            isFinished: isFinished,
                            votes: roundVotes
                        )

                        if isFinished {
                            // Игра завершена - переходим к экрану победителя
                            AppLogger.shared.debug("🏆 MovieBattleViewModel: Game finished, showing winner", category: .ui)

                            // Проверяем победителя в текущем состоянии (может быть обновлен или нет)
                            let winner = self.winnerMovie
                            if let winner = winner {
                                AppLogger.shared.debug(
                                    "MovieBattleViewModel: Winner found: \(winner.originalTitle), finalPosition: \(winner.finalPosition ?? -1)", category: .ui)
                            } else {
                                AppLogger.shared.warning(
                                    "MovieBattleViewModel: Winner not found in current state, checking filteredBattle...", category: .ui)
                                // Проверяем в filteredBattle
                                let winnerInFiltered =
                                    filteredBattle.status == .finished
                                    && {
                                        if let winner = filteredBattle.movies?.first(where: {
                                            $0.finalPosition == 1
                                        }) {
                                            AppLogger.shared.debug(
                                                "MovieBattleViewModel: Winner found in filteredBattle: \(winner.originalTitle)", category: .ui)
                                            return true
                                        }
                                        if let remaining = filteredBattle.movies?.filter({
                                            !$0.isEliminated
                                        }),
                                            remaining.count == 1,
                                            let winner = remaining.first
                                        {
                                            AppLogger.shared.debug(
                                                "MovieBattleViewModel: Winner found in filteredBattle (remaining): \(winner.originalTitle)", category: .ui)
                                            return true
                                        }
                                        return false
                                    }()

                                if !winnerInFiltered {
                                    AppLogger.shared.warning(
                                        "MovieBattleViewModel: Winner not found in filteredBattle, refreshing battle data", category: .ui)
                                    Task {
                                        await self.loadBattle(id: battle.id)
                                    }
                                }
                            }

                            self.currentPhase = .finished
                            self.showingResults = true
                        } else {
                            // Показываем результаты раунда
                            AppLogger.shared.debug("📊 MovieBattleViewModel: Showing round results", category: .ui)
                            self.currentPhase = .roundResult
                        }
                    } else {
                        AppLogger.shared.warning(
                            "MovieBattleViewModel: Ignoring round complete event for round \(roundNumber) - current round is \(currentRound)", category: .socket)
                        // Просто обновляем фазу без установки roundResult
                        self.updatePhase()
                    }
                } else {
                    AppLogger.shared.warning(
                        "MovieBattleViewModel: Could not find eliminated movie with id: \(eliminatedMovieId)", category: .socket)
                    // Если не нашли фильм, пытаемся найти его в обновленном battle
                    // или просто обновляем фазу
                    if isFinished {
                        self.currentPhase = .finished
                        self.showingResults = true
                        self.roundResult = nil
                    } else {
                        // Обновляем фазу, чтобы перейти к следующему раунду
                        self.roundResult = nil
                        self.updatePhase()
                    }
                }
            }
        }

        socketManager?.connectIfNeeded()
        // joinRoom будет вызван автоматически после подключения через обработчик connect
    }

    deinit {
        socketManager?.disconnect()
    }
}
