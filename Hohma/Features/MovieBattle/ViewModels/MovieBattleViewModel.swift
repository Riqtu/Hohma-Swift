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
            let currentUserId = trpcService.currentUser?.id
            let isParticipant =
                loadedBattle.participants?.contains { $0.userId == currentUserId } ?? false

            // Если пользователь не участник и игра еще не началась - автоматически присоединяем
            if !isParticipant && currentUserId != nil
                && (loadedBattle.status == .created || loadedBattle.status == .collecting)
            {
                do {
                    loadedBattle = try await service.joinBattle(battleId: id)
                } catch {
                    // Если не удалось присоединиться, продолжаем с текущим состоянием
                    print(
                        "⚠️ Не удалось автоматически присоединиться к игре: \(error.localizedDescription)"
                    )
                }
            }

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
                        print(
                            "🛡️ MovieBattleViewModel: Loaded battle doesn't contain finished game with winner, keeping current state"
                        )
                        print(
                            "   Current winner: \(currentWinner.originalTitle), finalPosition: \(currentWinner.finalPosition ?? -1)"
                        )
                        print(
                            "   Loaded status: \(filteredBattle.status), movies count: \(filteredBattle.movies?.count ?? 0)"
                        )
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
                            print(
                                "⚠️ MovieBattleViewModel: Loaded battle has different winner, updating state"
                            )
                            print(
                                "   Current winner: \(currentWinner.originalTitle), Loaded winner: \(loadedWinner.originalTitle)"
                            )
                        } else {
                            print(
                                "✅ MovieBattleViewModel: Loaded battle has same winner or winner confirmed, updating state"
                            )
                        }
                    }
                }

                self.battle = filteredBattle

                // Если игра завершена, проверяем наличие победителя
                if filteredBattle.status == .finished {
                    print("🔄 MovieBattleViewModel: Loaded finished battle, checking winner")
                    print(
                        "   Battle status: \(filteredBattle.status), movies count: \(filteredBattle.movies?.count ?? 0)"
                    )

                    // Проверяем победителя напрямую в filteredBattle
                    let winner: MovieCard? = {
                        // Сначала ищем по finalPosition
                        if let winner = filteredBattle.movies?.first(where: {
                            $0.finalPosition == 1
                        }) {
                            print(
                                "✅ MovieBattleViewModel: Winner found by finalPosition: \(winner.originalTitle)"
                            )
                            return winner
                        }
                        // Если игра завершена и остался только один не выбывший фильм - он победитель
                        if let remainingMovies = filteredBattle.movies?.filter({ !$0.isEliminated }
                        ),
                            remainingMovies.count == 1
                        {
                            print(
                                "✅ MovieBattleViewModel: Winner found by remaining: \(remainingMovies.first?.originalTitle ?? "unknown")"
                            )
                            return remainingMovies.first
                        }
                        return nil
                    }()

                    if let winner = winner {
                        print(
                            "✅ MovieBattleViewModel: Winner confirmed after load: \(winner.originalTitle), finalPosition: \(winner.finalPosition ?? -1)"
                        )
                    } else {
                        print("⚠️ MovieBattleViewModel: Winner not found after load")
                        if let movies = filteredBattle.movies {
                            print("   All movies:")
                            for movie in movies {
                                print(
                                    "     - \(movie.originalTitle): finalPosition=\(movie.finalPosition ?? -1), eliminatedAtRound=\(movie.eliminatedAtRound ?? -1)"
                                )
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
                self.battle = updatedBattle
                self.updatePhase()
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
                        print(
                            "🛡️ MovieBattleViewModel: Vote response doesn't contain finished game with winner, keeping current state"
                        )
                        print(
                            "   Current status: \(currentBattle.status), Response status: \(filteredBattle.status)"
                        )
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
            print("✅ WinnerMovie: Found by finalPosition = 1")
            return winner
        }

        // Если игра завершена и остался только один не выбывший фильм - он победитель
        if let remainingMovies = battle.movies?.filter({ !$0.isEliminated }),
            remainingMovies.count == 1
        {
            print("✅ WinnerMovie: Found by remaining movies (count = 1)")
            return remainingMovies.first
        }

        // Fallback: ищем фильм с finalPosition == 1 напрямую
        if let winner = battle.movies?.first(where: { $0.finalPosition == 1 }) {
            print("✅ WinnerMovie: Found by finalPosition == 1 (direct check)")
            return winner
        }

        print(
            "⚠️ WinnerMovie: No winner found. Status: \(battle.status), Movies count: \(battle.movies?.count ?? 0)"
        )
        if let movies = battle.movies {
            for movie in movies {
                print(
                    "   Movie: \(movie.originalTitle), finalPosition: \(movie.finalPosition ?? -1), eliminatedAtRound: \(movie.eliminatedAtRound ?? -1)"
                )
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
                print("⚠️ MovieBattleViewModel: Failed to filter movies: \(error)")
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
            print("🔄 MovieBattleViewModel: Disconnecting old socket manager")
            existingManager.disconnect()
        }

        print("🔄 MovieBattleViewModel: Setting up socket for battle \(battleId)")
        let socketAdapter = SocketIOServiceAdapter()
        socketManager = MovieBattleSocketManager(
            socket: socketAdapter, battleId: battleId, userId: userId)

        socketManager?.onBattleUpdate = { [weak self] battle in
            Task { @MainActor in
                guard let self = self else { return }
                print("🔄 MovieBattleViewModel: Received battle update via socket")

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
                    print(
                        "🛡️ MovieBattleViewModel: Battle already finished with winner: \(currentWinner.originalTitle)"
                    )

                    // Проверяем, есть ли завершенная игра с победителем в новом обновлении
                    // Важно: проверяем не только наличие победителя, но и статус FINISHED
                    let hasFinishedGameWithWinner =
                        filteredBattle.status == .finished
                        && {
                            // Проверяем по finalPosition
                            if let winner = filteredBattle.movies?.first(where: {
                                $0.finalPosition == 1
                            }) {
                                print(
                                    "✅ MovieBattleViewModel: Winner found in new update by finalPosition: \(winner.originalTitle)"
                                )
                                return true
                            }
                            // Проверяем по единственному не выбывшему фильму
                            if let remaining = filteredBattle.movies?.filter({ !$0.isEliminated }),
                                remaining.count == 1,
                                let winner = remaining.first
                            {
                                print(
                                    "✅ MovieBattleViewModel: Winner found in new update by remaining: \(winner.originalTitle)"
                                )
                                return true
                            }
                            print("⚠️ MovieBattleViewModel: No winner found in new update")
                            return false
                        }()

                    if !hasFinishedGameWithWinner {
                        print(
                            "🛡️ MovieBattleViewModel: Ignoring battle update - new update doesn't contain finished game with winner, keeping current state"
                        )
                        print(
                            "   Current winner: \(currentWinner.originalTitle), finalPosition: \(currentWinner.finalPosition ?? -1)"
                        )
                        print(
                            "   New update status: \(filteredBattle.status)"
                        )
                        if let newMovies = filteredBattle.movies {
                            print("   New update movies count: \(newMovies.count)")
                            for movie in newMovies {
                                print(
                                    "     - \(movie.originalTitle): finalPosition=\(movie.finalPosition ?? -1), eliminatedAtRound=\(movie.eliminatedAtRound ?? -1)"
                                )
                            }
                        }
                        return
                    }

                    print(
                        "✅ MovieBattleViewModel: New update contains finished game with winner, updating state"
                    )
                }

                // Обновляем состояние
                self.battle = filteredBattle

                // Если игра только что завершилась или была завершена, убеждаемся что показываем победителя
                if filteredBattle.status == .finished {
                    print("🏆 MovieBattleViewModel: Battle finished, checking winner")
                    if let winner = self.winnerMovie {
                        print("✅ MovieBattleViewModel: Winner found: \(winner.originalTitle)")
                    } else {
                        print(
                            "⚠️ MovieBattleViewModel: Winner not found yet, will refresh battle data"
                        )
                        // Если победитель не найден, запрашиваем обновленные данные с сервера
                        Task {
                            await self.loadBattle(id: filteredBattle.id)
                        }
                    }
                }

                self.updatePhase()

                // Обновляем прогресс генерации для всех фильмов (используем отфильтрованные)
                if let movies = filteredBattle.movies {
                    print(
                        "🔄 MovieBattleViewModel: Updating generation progress for \(movies.count) movies"
                    )
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
                    print("✅ MovieBattleViewModel: Generation progress updated, UI should refresh")
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

                print(
                    "🔄 MovieBattleViewModel: Received generation progress - movieCardId: \(movieCardId), status: \(status.rawValue)"
                )

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
                print("✅ MovieBattleViewModel: Updated generationProgress for \(movieCardId)")

                // Перезагружаем игру для синхронизации
                // Это гарантирует, что все данные актуальны и UI обновится
                // НО: не перезагружаем, если игра уже завершена с победителем
                if let battleId = self.battleId {
                    // Проверяем, не завершена ли игра уже
                    let isFinished = self.battle?.status == .finished && self.winnerMovie != nil

                    if isFinished {
                        print(
                            "🛡️ MovieBattleViewModel: Game already finished with winner, skipping reload to preserve state"
                        )
                        return
                    }

                    print("🔄 MovieBattleViewModel: Reloading battle from API...")
                    do {
                        let updatedBattle = try await self.service.getBattleById(
                            id: battleId,
                            includeMovies: true,
                            includeParticipants: true,
                            includeVotes: false
                        )

                        print("✅ MovieBattleViewModel: Battle reloaded, updating UI")

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
                                print(
                                    "🛡️ MovieBattleViewModel: Reloaded battle doesn't contain finished game with winner, keeping current state"
                                )
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

                        print("✅ MovieBattleViewModel: UI should be updated now")
                    } catch {
                        print("⚠️ Ошибка обновления фильма: \(error.localizedDescription)")
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
                print(
                    "🔄 MovieBattleViewModel: Received round complete event - roundNumber: \(roundNumber), eliminatedMovieId: \(eliminatedMovieId), isFinished: \(isFinished)"
                )

                // Проверяем, не является ли это событие для уже завершенного раунда
                // Если текущий раунд битвы уже больше, чем roundNumber из события, игнорируем его
                if let currentBattle = self.battle,
                    currentBattle.currentRound > roundNumber
                {
                    print(
                        "⚠️ MovieBattleViewModel: Ignoring round complete event for round \(roundNumber) - current round is \(currentBattle.currentRound)"
                    )
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
                        print(
                            "🛡️ MovieBattleViewModel: Round complete - new update doesn't contain finished game with winner, keeping current battle state"
                        )
                        print("   Current winner: \(currentWinner.originalTitle)")
                        print("   New update status: \(filteredBattle.status)")
                        shouldUpdateBattle = false
                    } else {
                        print(
                            "✅ MovieBattleViewModel: Round complete - new update contains finished game with winner, updating battle state"
                        )
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
                    print(
                        "✅ MovieBattleViewModel: Found eliminated movie: \(eliminatedMovie.originalTitle)"
                    )

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
                            print("🏆 MovieBattleViewModel: Game finished, showing winner")

                            // Проверяем победителя в текущем состоянии (может быть обновлен или нет)
                            let winner = self.winnerMovie
                            if let winner = winner {
                                print(
                                    "✅ MovieBattleViewModel: Winner found: \(winner.originalTitle), finalPosition: \(winner.finalPosition ?? -1)"
                                )
                            } else {
                                print(
                                    "⚠️ MovieBattleViewModel: Winner not found in current state, checking filteredBattle..."
                                )
                                // Проверяем в filteredBattle
                                let winnerInFiltered =
                                    filteredBattle.status == .finished
                                    && {
                                        if let winner = filteredBattle.movies?.first(where: {
                                            $0.finalPosition == 1
                                        }) {
                                            print(
                                                "✅ MovieBattleViewModel: Winner found in filteredBattle: \(winner.originalTitle)"
                                            )
                                            return true
                                        }
                                        if let remaining = filteredBattle.movies?.filter({
                                            !$0.isEliminated
                                        }),
                                            remaining.count == 1,
                                            let winner = remaining.first
                                        {
                                            print(
                                                "✅ MovieBattleViewModel: Winner found in filteredBattle (remaining): \(winner.originalTitle)"
                                            )
                                            return true
                                        }
                                        return false
                                    }()

                                if !winnerInFiltered {
                                    print(
                                        "⚠️ MovieBattleViewModel: Winner not found in filteredBattle, refreshing battle data"
                                    )
                                    Task {
                                        await self.loadBattle(id: battle.id)
                                    }
                                }
                            }

                            self.currentPhase = .finished
                            self.showingResults = true
                        } else {
                            // Показываем результаты раунда
                            print("📊 MovieBattleViewModel: Showing round results")
                            self.currentPhase = .roundResult
                        }
                    } else {
                        print(
                            "⚠️ MovieBattleViewModel: Ignoring round complete event for round \(roundNumber) - current round is \(currentRound)"
                        )
                        // Просто обновляем фазу без установки roundResult
                        self.updatePhase()
                    }
                } else {
                    print(
                        "⚠️ MovieBattleViewModel: Could not find eliminated movie with id: \(eliminatedMovieId)"
                    )
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
