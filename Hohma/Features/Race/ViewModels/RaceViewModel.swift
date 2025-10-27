import Foundation
import SwiftUI

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
    @Published var isMyTurn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var diceRoll: Int = 0
    @Published var canMakeMove: Bool = false

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

    init() {
        // Инициализация с пустыми данными для preview
    }

    func loadRace(_ race: Race) {
        self.race = race
        self.raceId = race.id
        self.participants = race.participants ?? []

        // Находим текущего пользователя среди участников
        if let currentUserId = trpcService.currentUser?.id {
            currentUserParticipant = participants.first { $0.userId == currentUserId }
        }

        generateRaceCells()
        updateGameState()
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

        // Все участники могут делать ход одновременно, если скачка активна
        canMakeMove =
            race.status == .running && currentUserParticipant != nil
            && !(currentUserParticipant?.isFinished ?? true)

        // Определяем, очередь ли текущего пользователя (упрощенная логика)
        isMyTurn = canMakeMove
    }

    func makeMove() {
        print("🎲 makeMove() вызвана")
        guard canMakeMove, let raceId = raceId, !isAnimating else {
            print(
                "❌ makeMove() заблокирована: canMakeMove=\(canMakeMove), raceId=\(raceId != nil), isAnimating=\(isAnimating)"
            )
            return
        }

        print("✅ makeMove() выполняется")
        isLoading = true
        errorMessage = nil

        // Сохраняем текущие позиции для анимации
        let currentPositions = Dictionary(
            uniqueKeysWithValues: participants.map { ($0.id, $0.currentPosition) })

        print("📍 Сохранены текущие позиции: \(currentPositions)")

        // Генерируем случайный бросок кубика (1-6) для всех участников
        let diceRoll = Int.random(in: 1...6)
        self.diceRoll = diceRoll
        print("🎲 Бросок кубика: \(diceRoll)")

        let request: [String: Any] = [
            "raceId": raceId,
            "diceRoll": diceRoll,
        ]

        Task {
            do {
                print("🌐 Отправляем запрос на сервер...")
                let _: MakeMoveResponse = try await trpcService.executePOST(
                    endpoint: "race.makeMove",
                    body: request
                )
                print("✅ Ответ от сервера получен")

                await MainActor.run {
                    print("🔄 Обновляем данные после хода...")
                    // Сначала обновляем данные после хода
                    self.refreshRaceAndStartAnimation(withPreviousPositions: currentPositions)
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
                // Очищаем состояние анимации
                self.animationProgress = 0.0
                self.currentAnimationStep = 0
                self.totalAnimationSteps = 0
                self.previousPositions.removeAll()
                self.participantAnimationSteps.removeAll()
                self.currentStepPosition.removeAll()
                self.isJumping.removeAll()
                self.animationStepProgress.removeAll()
            }
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
