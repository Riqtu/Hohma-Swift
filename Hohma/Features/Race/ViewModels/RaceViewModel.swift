import Foundation
import SwiftUI

final class RaceSocketManager {
    private let socket: SocketIOServiceAdapter

    // Callbacks to VM/UI
    var onRaceUpdate: (([String: Any]) -> Void)?
    var onRaceState: (([String: Any]) -> Void)?
    var onRaceDiceOpen: (([String: Any]) -> Void)?
    var onRaceDiceResults: (([String: Any]) -> Void)?
    var onRaceDiceNext: (([String: Any]) -> Void)?
    var onRaceFinish: (([String: Any]) -> Void)?

    init(socket: SocketIOServiceAdapter) {
        self.socket = socket
        setupHandlers()
    }

    private func setupHandlers() {
        socket.on(.connect) { _ in
            print("🔌 RaceSocketManager: connected")
        }

        socket.on(.raceUpdate) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🏁 RaceSocketManager: race:update -> keys=\(Array(json.keys))")
                    self.onRaceUpdate?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:update payload: \(error)")
            }
        }

        socket.on(.raceState) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📦 RaceSocketManager: race:state received")
                    self.onRaceState?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:state payload: \(error)")
            }
        }

        socket.on(.raceDiceOpen) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🎲 RaceSocketManager: race:dice:open received")
                    self.onRaceDiceOpen?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:dice:open payload: \(error)")
            }
        }

        socket.on(.raceDiceResults) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🎲 RaceSocketManager: race:dice:results received")
                    self.onRaceDiceResults?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:dice:results payload: \(error)")
            }
        }

        socket.on(.raceDiceNext) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("➡️ RaceSocketManager: race:dice:next received")
                    self.onRaceDiceNext?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:dice:next payload: \(error)")
            }
        }

        socket.on(.raceFinish) { [weak self] data in
            guard let self = self else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🏁 RaceSocketManager: race:finish received")
                    self.onRaceFinish?(json)
                }
            } catch {
                print("❌ RaceSocketManager: failed to parse race:finish payload: \(error)")
            }
        }
    }

    func connectIfNeeded() {
        if !socket.isConnected && !socket.isConnecting {
            socket.connect()
        }
    }

    func joinRoom(raceId: String, userId: String) {
        let payload: [String: Any] = [
            "roomId": raceId,
            "userId": userId,
        ]
        socket.emit(.joinRoom, data: payload)
    }

    func leaveRoom(raceId: String) {
        socket.emit(.leaveRoom, data: ["roomId": raceId])
    }

    func requestState(raceId: String) {
        socket.emit(.raceRequestState, roomId: raceId, data: [:])
    }

    func emitRaceUpdate(raceId: String, payload: [String: Any]) {
        socket.emit(.raceUpdate, roomId: raceId, data: payload)
    }

    func emitDiceOpen(raceId: String, roundId: String) {
        socket.emit(.raceDiceOpen, roomId: raceId, data: ["roundId": roundId])
    }

    func emitDiceResults(raceId: String, roundId: String, diceResults: [String: Int]) {
        socket.emit(
            .raceDiceResults,
            roomId: raceId,
            data: [
                "roundId": roundId,
                "diceResults": diceResults,
            ]
        )
    }

    func emitDiceNext(raceId: String) {
        socket.emit(.raceDiceNext, roomId: raceId, data: [:])
    }

    func emitFinish(raceId: String, finishingParticipants: [String], winnerId: String?) {
        var payload: [String: Any] = ["finishingParticipants": finishingParticipants]
        if let w = winnerId { payload["winnerId"] = w }
        socket.emit(.raceFinish, roomId: raceId, data: payload)
    }
}

// Модель данных для ячейки дороги
struct RaceCellData: Identifiable {
    let id = UUID()
    let position: Int
    let isActive: Bool
    let type: CellType
    let participants: [ParticipantPosition]  // Участники на этой позиции

    enum CellType {
        case normal, boost, obstacle, bonus, finish
    }
}

// Позиция участника на дороге
struct ParticipantPosition: Identifiable {
    let id = UUID()
    let participantId: String
    let userId: String
    let userName: String
    let avatarUrl: String?
    let isCurrentUser: Bool
}

class RaceViewModel: ObservableObject, TRPCServiceProtocol {
    @Published var race: Race?
    @Published var raceCells: [RaceCellData] = []
    @Published var participants: [RaceParticipant] = []
    @Published var currentUserParticipant: RaceParticipant?
    @Published var myParticipants: [RaceParticipant] = []
    @Published var isMyTurn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var diceRoll: Int = 0
    @Published var canMakeMove: Bool = false

    // Состояние финиширования
    @Published var raceFinished: Bool = false
    @Published var finishingParticipants: [String] = []
    @Published var winnerId: String?
    @Published var showingWinnerSelection: Bool = false

    // Состояние экрана кубиков
    @Published var showingDiceRoll: Bool = false
    @Published var diceResults: [String: Int] = [:]
    @Published var isDiceInitiator: Bool = false
    @Published var currentDiceRoundId: String?

    // Состояние анимации
    @Published var isAnimating: Bool = false
    @Published var animationProgress: Double = 0.0
    @Published var previousPositions: [String: Int] = [:]  // participantId -> previous position
    @Published var currentAnimationStep: Int = 0  // Текущий шаг анимации
    @Published var totalAnimationSteps: Int = 0  // Общее количество шагов

    // Система одновременной пошаговой анимации
    @Published var participantAnimationSteps: [String: [Int]] = [:]  // participantId -> массив шагов
    @Published var currentStepPosition: [String: Double] = [:]  // participantId -> текущая позиция в анимации (дробная)
    @Published var isJumping: [String: Bool] = [:]  // participantId -> прыгает ли сейчас
    @Published var animationStepProgress: [String: Double] = [:]  // participantId -> прогресс текущего шага (0.0-1.0)

    private var raceId: String?
    private var raceSocketManager: RaceSocketManager?
    // Флаг подавления показа экрана победителя до завершения анимации
    @Published private var suppressWinnerPresentation: Bool = false

    init() {
        // Инициализация с пустыми данными для preview
    }

    deinit {
        // Очищаем кэш аватарок при уничтожении ViewModel
        clearAvatarCache()
    }

    func loadRace(_ race: Race) {
        self.race = race
        self.raceId = race.id
        self.participants = race.participants ?? []

        // Находим текущего пользователя среди участников
        if let currentUserId = trpcService.currentUser?.id {
            let mine = participants.filter { $0.userId == currentUserId }
            myParticipants = mine
            currentUserParticipant = mine.first
        } else {
            myParticipants = []
            currentUserParticipant = nil
        }

        // Инициализируем позиции участников для отображения аватарок
        initializeParticipantPositions()

        generateRaceCells()
        updateGameState()

        // Проверяем, завершена ли гонка
        if race.status == .finished {
            handleFinishedRace()
        }

        // Предзагружаем аватарки участников для оптимизации отображения
        preloadParticipantAvatars()

        // ========= Socket wiring =========
        setupRaceSocketIfNeeded()
        joinRaceRoomIfPossible()
    }

    private func initializeParticipantPositions() {
        // Инициализируем позиции участников для корректного отображения аватарок
        for participant in participants {
            currentStepPosition[participant.id] = Double(participant.currentPosition)
            isJumping[participant.id] = false
            animationStepProgress[participant.id] = 1.0
        }
    }

    /// Предзагрузка аватарок участников для оптимизации отображения
    private func preloadParticipantAvatars() {
        AvatarCacheService.shared.preloadAvatars(for: participants)
    }

    /// Очистка кэша аватарок при завершении скачки
    private func clearAvatarCache() {
        // Очищаем кэш аватарок для освобождения памяти
        for participant in participants {
            AvatarCacheService.shared.clearCache(for: participant.user.id)
        }
    }

    private func handleFinishedRace() {
        // Предпочитаем победителя, зафиксированного на сервере
        if let serverWinnerId = race?.winnerParticipantId,
            let winner = participants.first(where: { $0.id == serverWinnerId })
        {
            self.winnerId = winner.id
            print(
                "🏁 Гонка завершена! Победитель (с сервера): \(winner.user.name ?? winner.user.username ?? "Неизвестно")"
            )
        } else if let winner = participants.first(where: { $0.finalPosition == 1 }) {
            self.winnerId = winner.id
            print(
                "🏁 Гонка завершена! Победитель по finalPosition: \(winner.user.name ?? winner.user.username ?? "Неизвестно")"
            )
        }

        // Собираем список финишировавших
        let finishers =
            participants
            .filter { ($0.finalPosition ?? 0) > 0 }
            .sorted { ($0.finalPosition ?? Int.max) < ($1.finalPosition ?? Int.max) }
            .map { $0.id }
        self.finishingParticipants = finishers

        // Презентацию результатов откладываем, если идет обновление перед анимацией
        guard !suppressWinnerPresentation else { return }

        // Если победитель уже определён сервером
        if self.winnerId != nil {
            // Если несколько участников финишировали одновременно, показываем анимацию выбора
            // (хотя победитель уже определен сервером - это для визуального эффекта)
            if self.finishingParticipants.count > 1 {
                self.showingWinnerSelection = true
                self.raceFinished = false
            } else {
                // Один финишер - сразу показываем результат
                self.raceFinished = true
            }
        } else if self.finishingParticipants.count > 1 {
            // Несколько финишировали, но победитель еще не определен сервером
            // (это не должно происходить, но на всякий случай)
            self.showingWinnerSelection = true
            self.raceFinished = false
        } else if self.finishingParticipants.count == 1 {
            // Единственный финишер — он победитель
            self.winnerId = self.finishingParticipants.first
            self.raceFinished = true
        }

        // Очищаем кэш аватарок при завершении скачки для освобождения памяти
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.clearAvatarCache()
        }
    }

    private func setupRaceSocketIfNeeded() {
        if raceSocketManager == nil {
            let socketAdapter = SocketIOServiceAdapter()
            let manager = RaceSocketManager(socket: socketAdapter)
            manager.onRaceUpdate = { [weak self] (payload: [String: Any]) in
                guard let self = self else { return }
                // При получении обновления — освежаем состояние и запускаем анимацию от предыдущих позиций
                let prev = Dictionary(
                    uniqueKeysWithValues: self.participants.map { ($0.id, $0.currentPosition) })
                self.refreshRaceAndStartAnimation(withPreviousPositions: prev)
            }
            manager.onRaceState = { [weak self] (_: [String: Any]) in
                self?.refreshRace()
            }
            // Открыть экран кубиков (только фиксация раунда; у клиентов окно открываем по results)
            manager.onRaceDiceOpen = { [weak self] (payload: [String: Any]) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    // Устанавливаем текущий раунд из payload, если есть
                    if let roundId = payload["roundId"] as? String {
                        // Новый раунд — сбрасываем старые результаты
                        if self.currentDiceRoundId != roundId {
                            self.currentDiceRoundId = roundId
                            self.diceResults = [:]
                        }
                    }
                    self.isDiceInitiator = false
                    // Не открываем окно здесь, чтобы исключить пустые значения; откроем по results
                }
            }
            // Показать результаты кубиков синхронно (визуально), не дергая HTTP
            manager.onRaceDiceResults = { [weak self] (payload: [String: Any]) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let incomingRoundId = payload["roundId"] as? String
                    // Если roundId не установлен — устанавливаем его по первым пришедшим результатам
                    if self.currentDiceRoundId == nil, let r = incomingRoundId {
                        self.currentDiceRoundId = r
                        self.diceResults = [:]
                    }
                    // Применяем только результаты текущего раунда (игнорируем старые)
                    if incomingRoundId == nil || incomingRoundId == self.currentDiceRoundId {
                        if let dice = payload["diceResults"] as? [String: Int] {
                            self.diceResults = dice
                        }
                    }
                    // Не переоткрываем окно у инициатора при собственном broadcast
                    if !self.isDiceInitiator {
                        self.showingDiceRoll = true
                    }
                }
            }
            // Закрыть экран кубиков у всех по нажатию "Дальше"
            manager.onRaceDiceNext = { [weak self] (_: [String: Any]) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.showingDiceRoll = false
                }
            }
            // Показать победителя/рандом победителя синхронно
            manager.onRaceFinish = { [weak self] (payload: [String: Any]) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let fins = payload["finishingParticipants"] as? [String] {
                        self.finishingParticipants = fins
                    }
                    if let win = payload["winnerId"] as? String {
                        self.winnerId = win
                        // Если несколько участников финишировали, показываем анимацию выбора победителя
                        // (хотя победитель уже определен сервером)
                        if let fins = payload["finishingParticipants"] as? [String], fins.count > 1
                        {
                            self.showingWinnerSelection = true
                        }
                    }
                    // После того как локальная анимация завершится, UI покажет победителя автоматически
                }
            }
            raceSocketManager = manager
            manager.connectIfNeeded()
        }
    }

    private func joinRaceRoomIfPossible() {
        guard let raceId = raceId, let userId = trpcService.currentUser?.id else { return }
        raceSocketManager?.joinRoom(raceId: raceId, userId: userId)
        // Запросим актуальное состояние (если кто-то в комнате ответит)
        raceSocketManager?.requestState(raceId: raceId)
    }

    private func generateRaceCells() {
        guard let race = race else { return }

        raceCells = (0..<race.road.length).map { position in
            let cellType: RaceCellData.CellType
            if let roadCell = race.road.cells?.first(where: { $0.position == position }) {
                switch roadCell.cellType {
                case .normal: cellType = .normal
                case .boost: cellType = .boost
                case .obstacle: cellType = .obstacle
                case .bonus: cellType = .bonus
                case .finish: cellType = .finish
                }
            } else {
                cellType = position == race.road.length - 1 ? .finish : .normal
            }

            // Находим участников на этой позиции
            let participantsOnPosition = participants.compactMap {
                participant -> ParticipantPosition? in
                guard participant.currentPosition == position else { return nil }

                return ParticipantPosition(
                    participantId: participant.id,
                    userId: participant.userId,
                    userName: participant.user.name ?? participant.user.username ?? "Неизвестно",
                    avatarUrl: participant.user.avatarUrl,
                    isCurrentUser: participant.userId == trpcService.currentUser?.id
                )
            }

            return RaceCellData(
                position: position,
                isActive: participantsOnPosition.contains { $0.isCurrentUser },
                type: cellType,
                participants: participantsOnPosition
            )
        }
    }

    private func updateGameState() {
        guard let race = race else { return }

        // Все участники могут делать ход, если скачка активна
        // Сервер сам определит, кто должен пропустить ход
        canMakeMove =
            race.status == .running && currentUserParticipant != nil
            && !(currentUserParticipant?.isFinished ?? true)
            && !raceFinished

        // Определяем, очередь ли текущего пользователя (упрощенная логика)
        isMyTurn = canMakeMove

        print("🎮 Любой участник может инициировать ход всех участников")
    }

    func joinRace(movie: RaceMovieSelection, completion: (() -> Void)? = nil) {
        guard let raceId = race?.id else {
            errorMessage = "Скачка не найдена"
            return
        }
        isLoading = true
        errorMessage = nil

        var request: [String: Any] = ["raceId": raceId]
        movie.requestPayload.forEach { request[$0.key] = $0.value }

        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.joinRace",
                    body: request
                )

                await MainActor.run {
                    self.isLoading = false
                    self.refreshRace()
                    NotificationCenter.default.post(name: .raceUpdated, object: nil)
                    completion?()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка присоединения: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    var canJoinCurrentRace: Bool {
        guard let race = race else { return false }
        let currentCount = race.participants?.count ?? participants.count
        return (race.status == .created || race.status == .waiting)
            && currentCount < race.maxPlayers
    }

    var canStartRace: Bool {
        guard let race = race,
            let currentUserId = trpcService.currentUser?.id
        else { return false }

        let participantCount = race.participants?.count ?? participants.count
        return race.status == .created && participantCount >= 2
            && race.creator.id == currentUserId
    }

    func makeMove() {
        print("🎲 makeMove() вызвана")
        guard canMakeMove, raceId != nil, !isAnimating else {
            print(
                "❌ makeMove() заблокирована: canMakeMove=\(canMakeMove), raceId=\(raceId != nil), isAnimating=\(isAnimating)"
            )
            return
        }

        print("✅ makeMove() выполняется")

        // Старт нового раунда броска
        let roundId = UUID().uuidString
        self.currentDiceRoundId = roundId
        self.diceResults = [:]
        showingDiceRoll = true
        isDiceInitiator = true

        // Инициатор генерирует ОДИНСТВЕННЫЕ авторитетные результаты для всех участников
        var generatedResults: [String: Int] = [:]
        for participant in participants {
            generatedResults[participant.id] = Int.random(in: 1...6)
        }
        // Фиксируем локально и сразу рассылаем всем
        self.diceResults = generatedResults
        if let raceId = raceId {
            raceSocketManager?.emitDiceOpen(raceId: raceId, roundId: roundId)
            raceSocketManager?.emitDiceResults(
                raceId: raceId,
                roundId: roundId,
                diceResults: generatedResults
            )
        }
    }

    func executeMoveWithDiceResults(_ diceResults: [String: Int]) {
        guard let raceId = raceId else { return }

        // Локально фиксируем результаты для инициатора, так как сервер шлёт "остальным"
        self.diceResults = diceResults
        self.showingDiceRoll = true

        print("🎲 executeMoveWithDiceResults() вызвана с результатами: \(diceResults)")
        print("🎲 Отправляем на сервер diceResults: \(diceResults)")
        isLoading = true
        errorMessage = nil

        // Сохраняем текущие позиции для анимации
        let currentPositions = Dictionary(
            uniqueKeysWithValues: participants.map { ($0.id, $0.currentPosition) })

        print("📍 Сохранены текущие позиции: \(currentPositions)")

        // Используем результат кубика для текущего пользователя
        let currentUserParticipantId = currentUserParticipant?.id
        let diceRoll = diceResults[currentUserParticipantId ?? ""] ?? Int.random(in: 1...6)
        self.diceRoll = diceRoll
        print(
            "🎲 Бросок кубика для текущего пользователя (participantId: \(currentUserParticipantId ?? "nil")): \(diceRoll)"
        )

        let request: [String: Any] = [
            "raceId": raceId,
            "diceRoll": diceRoll,
            "diceResults": diceResults,  // Отправляем все результаты кубиков
        ]

        // Результаты уже были разосланы при открытии окна инициатором

        Task {
            do {
                print("🌐 Отправляем запрос на сервер...")
                let response: MakeMoveResponse = try await trpcService.executePOST(
                    endpoint: "race.makeMove",
                    body: request
                )
                print("✅ Ответ от сервера получен")

                await MainActor.run {
                    print("🔄 Обновляем данные после хода...")

                    // Проверяем, завершилась ли гонка
                    if response.raceFinished {
                        // Сохраняем информацию о завершении, но НЕ показываем экран победителя сразу
                        self.finishingParticipants = response.finishingParticipants ?? []
                        self.winnerId = response.winnerId
                        print("🏁 Гонка завершена! Победитель: \(self.winnerId ?? "неизвестно")")
                        print("🏁 Финишировавшие участники: \(self.finishingParticipants)")

                        // Сообщаем остальным о завершении гонки и победителе
                        self.raceSocketManager?.emitFinish(
                            raceId: raceId,
                            finishingParticipants: self.finishingParticipants,
                            winnerId: self.winnerId
                        )
                    }

                    // Сначала обновляем данные после хода
                    self.refreshRaceAndStartAnimation(withPreviousPositions: currentPositions)
                    // После успешного хода — уведомляем остальных через сокет, чтобы они обновились
                    self.raceSocketManager?.emitRaceUpdate(
                        raceId: raceId,
                        payload: [
                            "raceId": raceId,
                            "updatedAt": Int(Date().timeIntervalSince1970),
                        ]
                    )
                    self.isLoading = false
                }
            } catch {
                print("❌ Ошибка при выполнении хода: \(error)")
                await MainActor.run {
                    self.errorMessage = "Ошибка хода: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func startRace() {
        guard let raceId = race?.id else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.startRace",
                    body: ["raceId": raceId]
                )

                await MainActor.run {
                    self.isLoading = false
                    self.refreshRace()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка запуска скачки: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func diceNext() {
        if let raceId = race?.id {
            raceSocketManager?.emitDiceNext(raceId: raceId)
        }
        showingDiceRoll = false
    }

    func setWinner(participantId: String) {
        guard let raceId = race?.id else { return }

        // Если победитель уже определен сервером, просто закрываем экран выбора
        if winnerId == participantId {
            showingWinnerSelection = false
            raceFinished = true
            return
        }

        // Если победитель не определен, отправляем выбор на сервер (fallback для старых гонок)
        isLoading = true
        Task {
            do {
                let _: SuccessResponse = try await trpcService.executePOST(
                    endpoint: "race.setWinner",
                    body: [
                        "raceId": raceId,
                        "winnerParticipantId": participantId,
                    ]
                )

                await MainActor.run {
                    self.winnerId = participantId
                    self.showingWinnerSelection = false
                    self.raceFinished = true
                    self.isLoading = false
                    self.refreshRace()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка выбора победителя: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func startAnimation(withPreviousPositions previousPositions: [String: Int]) {
        print("🚀 startAnimation() вызвана")
        isAnimating = true

        // Сохраняем предыдущие позиции для анимации
        self.previousPositions = previousPositions

        // Подготавливаем шаги анимации для каждого участника
        prepareAnimationSteps()

        // Запускаем одновременную анимацию всех участников
        print("🎬 Запускаем одновременную анимацию всех участников")
        animateAllParticipantsSimultaneously()
    }

    private func prepareAnimationSteps() {
        participantAnimationSteps.removeAll()
        currentStepPosition.removeAll()
        isJumping.removeAll()
        animationStepProgress.removeAll()

        for participant in participants {
            guard let previousPos = previousPositions[participant.id] else { continue }
            let currentPos = participant.currentPosition
            let distance = currentPos - previousPos

            if distance > 0 {
                // Создаем массив шагов ВКЛЮЧАЯ начальную позицию
                var steps: [Int] = []
                // Начинаем с предыдущей позиции и идем до текущей
                for step in 0...distance {
                    steps.append(previousPos + step)
                }
                participantAnimationSteps[participant.id] = steps
                currentStepPosition[participant.id] = Double(previousPos)  // Начинаем с предыдущей позиции
                isJumping[participant.id] = false
                animationStepProgress[participant.id] = 0.0

                // Отладочная информация
                print(
                    "🚀 Участник \(participant.id): было \(previousPos), стало \(currentPos), шаги: \(steps)"
                )
            }
        }
    }

    private func animateAllParticipantsSimultaneously() {
        // Находим максимальное количество шагов среди всех участников
        let maxSteps = participantAnimationSteps.values.map { $0.count }.max() ?? 0

        print("🎬 Максимальное количество шагов: \(maxSteps)")

        // Анимируем все шаги одновременно
        animateStep(stepIndex: 0, maxSteps: maxSteps)
    }

    private func animateStep(stepIndex: Int, maxSteps: Int) {
        guard stepIndex < maxSteps else {
            print("✅ Все шаги анимированы - завершаем")
            finishAnimation()
            return
        }

        print("🎯 Анимируем шаг \(stepIndex + 1)/\(maxSteps)")

        // Анимируем всех участников на текущем шаге
        for participant in participants {
            guard let steps = participantAnimationSteps[participant.id],
                stepIndex < steps.count
            else { continue }

            let targetPosition = steps[stepIndex]

            print("🎯 Участник \(participant.id): шаг \(stepIndex), позиция \(targetPosition)")

            // Устанавливаем состояние прыжка
            isJumping[participant.id] = true

            // Обновляем позицию сразу на целую клетку
            currentStepPosition[participant.id] = Double(targetPosition)
            animationStepProgress[participant.id] = 1.0
        }

        // Тактильная обратная связь
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Пауза на клетке перед переходом к следующему шагу
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Завершаем прыжки всех участников
            for participant in self.participants {
                self.isJumping[participant.id] = false
            }

            // Переходим к следующему шагу
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.animateStep(stepIndex: stepIndex + 1, maxSteps: maxSteps)
            }
        }
    }

    private func finishAnimation() {
        // Финальная пауза
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.isAnimating = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Очищаем только состояние анимации, но НЕ сбрасываем позиции участников
                self.animationProgress = 0.0
                self.currentAnimationStep = 0
                self.totalAnimationSteps = 0
                self.previousPositions.removeAll()
                self.participantAnimationSteps.removeAll()

                // НЕ очищаем currentStepPosition, isJumping и animationStepProgress
                // чтобы аватарки участников остались видимыми на их финальных позициях
                // Эти значения будут обновлены при следующей анимации

                // Устанавливаем финальные позиции участников
                for participant in self.participants {
                    self.currentStepPosition[participant.id] = Double(participant.currentPosition)
                    self.isJumping[participant.id] = false
                    self.animationStepProgress[participant.id] = 1.0
                }

                // Разрешаем презентацию результатов и показываем победителя ПОСЛЕ анимации
                self.suppressWinnerPresentation = false
                self.checkAndShowWinnerAfterAnimation()
            }
        }
    }

    private func checkAndShowWinnerAfterAnimation() {
        // Проверяем, есть ли информация о завершении гонки
        guard !finishingParticipants.isEmpty, winnerId != nil else {
            print("🏁 Анимация завершена, но гонка не завершена")
            return
        }

        print("🏁 Анимация завершена! Показываем экран победителя")

        // Устанавливаем флаг завершения гонки
        self.raceFinished = true

        // Если несколько участников финишировали одновременно, показываем экран выбора победителя
        if self.finishingParticipants.count > 1 {
            print("🏁 Несколько участников финишировали, показываем экран выбора победителя")
            self.showingWinnerSelection = true
        } else {
            print("🏁 Один участник финишировал, показываем экран победителя")
            // Экран победителя уже будет показан через raceFinished = true
        }
    }

    func refreshRace() {
        guard let raceId = raceId else { return }

        Task {
            do {
                let response: Race = try await trpcService.executeGET(
                    endpoint: "race.getRaceById",
                    input: ["id": raceId, "includeParticipants": true]
                )

                await MainActor.run {
                    self.loadRace(response)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка обновления: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshRaceAndStartAnimation(withPreviousPositions previousPositions: [String: Int]) {
        guard let raceId = raceId else { return }

        Task {
            do {
                let response: Race = try await trpcService.executeGET(
                    endpoint: "race.getRaceById",
                    input: ["id": raceId, "includeParticipants": true]
                )

                await MainActor.run {
                    // Подавляем показ результатов до окончания анимации
                    self.suppressWinnerPresentation = true
                    self.loadRace(response)

                    print("🎬 Запускаем анимацию движения...")
                    // Запускаем анимацию движения с сохраненными позициями
                    self.startAnimation(withPreviousPositions: previousPositions)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка обновления: \(error.localizedDescription)"
                }
            }
        }
    }
}
