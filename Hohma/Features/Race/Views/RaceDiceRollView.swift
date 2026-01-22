import Inject
import SwiftUI

struct RaceDiceRollView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceDiceRollViewModel()
    let participants: [RaceParticipant]
    let initialDiceResults: [String: Int]
    let isInitiator: Bool
    let onNext: () -> Void
    let onDiceRollComplete: ([String: Int]) -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var showContinueButton = false

    var body: some View {
        ZStack {
            // Фон
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Заголовок
                Text("Бросок кубиков")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Список участников с кубиками
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ForEach(Array(participants.enumerated()), id: \.element.id) {
                            index, participant in
                            ParticipantDiceRow(
                                participant: participant,
                                diceValue: viewModel.diceResults[participant.id] ?? 0,
                                isAnimating: isAnimating,
                                animationDelay: Double(index) * 0.1
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)

                // Кнопка "Дальше"
                if showContinueButton {
                    Button(action: {
                        if isInitiator {
                            onDiceRollComplete(viewModel.diceResults)
                        }
                        onNext()  // синхронно закрываем всем
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Дальше")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("AccentColor"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            // Все клиенты используют только авторитетные результаты из VM
            if !initialDiceResults.isEmpty {
                viewModel.diceResults = initialDiceResults
                startDiceAnimation()
            } else {
                // ждём onChange(initialDiceResults)
                isAnimating = false
            }
        }
        .onChangeCompat(of: initialDiceResults.count, initial: false) { _, _ in
            // Если пришли результаты по сокету после открытия — применяем и запускаем анимацию
            if !initialDiceResults.isEmpty && !isInitiator {
                viewModel.diceResults = initialDiceResults
                if !isAnimating { startDiceAnimation() }
            }
        }
        .enableInjection()
    }

    private func startDiceAnimation() {
        // Используем только переданные результаты для синхронности
        guard !initialDiceResults.isEmpty || !viewModel.diceResults.isEmpty else { return }
        if viewModel.diceResults.isEmpty { viewModel.diceResults = initialDiceResults }

        // Запускаем анимацию
        withAnimation(.easeInOut(duration: 0.3)) {
            isAnimating = true
        }

        // Показываем кнопку "Дальше" через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showContinueButton = true
            }
        }
    }
}

struct ParticipantDiceRow: View {
    let participant: RaceParticipant
    let diceValue: Int
    let isAnimating: Bool
    let animationDelay: Double

    @State private var currentDiceValue = 0
    @State private var hasStartedAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                participantArtwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryTitle)
                        .font(.body)
                        .foregroundColor(.white)

                    Text(secondaryTitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Позиция: \(participant.currentPosition)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    if participant.skipNextTurn {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Пропуск хода")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()

                DiceView(
                    value: currentDiceValue,
                    isAnimating: isAnimating,
                    animationDelay: animationDelay,
                    skipNextTurn: participant.skipNextTurn
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(participantBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(participantBorderColor, lineWidth: 1)
                )
        )
        .onAppear {
            if isAnimating && !hasStartedAnimation {
                startDiceAnimation()
            }
        }
        .onChangeCompat(of: isAnimating, initial: false) { _, newValue in
            if newValue && !hasStartedAnimation {
                startDiceAnimation()
            }
        }
        .onChangeCompat(of: diceValue, initial: false) { _, newValue in
            if hasStartedAnimation {
                currentDiceValue = newValue
            } else if isAnimating {
                startDiceAnimation()
            }
        }
    }

    // MARK: - Computed Properties
    private var primaryTitle: String {
        participant.movieTitle ?? participant.user.name ?? participant.user.username ?? "Неизвестно"
    }

    private var secondaryTitle: String {
        if participant.movieTitle != nil {
            if let userName = participant.user.name ?? participant.user.username {
                return userName
            }
        }
        return "Игрок"
    }

    @ViewBuilder
    private var participantArtwork: some View {
        if let poster = participant.moviePosterUrl, !poster.isEmpty {
            RacePosterView(
                posterUrl: poster,
                title: participant.movieTitle,
                width: 40,
                height: 60,
                showTitle: false
            )
        } else {
            CachedAsyncImage(url: URL(string: participant.user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
        }
    }

    private var participantBackgroundColor: Color {
        if participant.skipNextTurn {
            return Color.red.opacity(0.2)
        } else {
            return Color.white.opacity(0.1)
        }
    }

    private var participantBorderColor: Color {
        if participant.skipNextTurn {
            return Color.red.opacity(0.6)
        } else {
            return Color.white.opacity(0.2)
        }
    }

    private func startDiceAnimation() {
        guard !hasStartedAnimation else { return }
        hasStartedAnimation = true

        // Запускаем анимацию кубика с задержкой
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
            animateDice()
        }
    }

    private func animateDice() {
        // Анимация кубика - показываем случайные значения
        // Синхронизируем с анимацией вращения (1.5 секунды)
        let animationSteps = 15  // Больше шагов для плавности
        let stepDuration = 0.1  // Быстрее смена для эффекта вращения

        for step in 0..<animationSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                withAnimation(.easeInOut(duration: stepDuration)) {
                    currentDiceValue = Int.random(in: 1...6)
                }
            }
        }

        // Устанавливаем финальное значение через 1.5 секунды (как вращение)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                currentDiceValue = diceValue
            }
        }
    }
}

struct DiceView: View {
    let value: Int
    let isAnimating: Bool
    let animationDelay: Double
    let skipNextTurn: Bool

    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var offsetY: CGFloat = 0
    @State private var hasAnimated = false

    var body: some View {
        ZStack {
            // Кубик
            RoundedRectangle(cornerRadius: 8)
                .fill(diceBackgroundColor)
                .frame(width: 45, height: 45)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(diceBorderColor, lineWidth: 2)
                )

            // Точки на кубике
            DiceDotsView(value: value)

            // Эффекты полей - только красные (пропуск хода)
            if skipNextTurn {
                // Красный эффект для пропуска хода
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    )
            }
        }
        .rotationEffect(.degrees(rotationAngle))  // Простое вращение по кругу
        .scaleEffect(scale)
        .offset(y: offsetY)  // Эффект подпрыгивания
        .onAppear {
            if isAnimating && !hasAnimated {
                startAnimation()
            }
        }
        .onChangeCompat(of: isAnimating, initial: false) { _, newValue in
            if newValue && !hasAnimated {
                startAnimation()
            }
        }
    }

    // MARK: - Computed Properties
    private var diceBackgroundColor: Color {
        if skipNextTurn {
            return Color.red.opacity(0.1)
        } else {
            return Color.white
        }
    }

    private var diceBorderColor: Color {
        if skipNextTurn {
            return Color.red.opacity(0.8)
        } else {
            return Color.black.opacity(0.3)
        }
    }

    private func startAnimation() {
        guard !hasAnimated else { return }
        hasAnimated = true

        // Сброс состояния
        rotationAngle = 0
        scale = 1.0
        offsetY = 0

        // Фаза 1: Подпрыгивание (0-0.5 сек)
        withAnimation(.easeOut(duration: 0.2)) {
            offsetY = -5
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.3)) {
                offsetY = 0
            }
        }

        // Фаза 2: Масштабирование (0.3-0.8 сек)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeIn(duration: 0.3)) {
                    scale = 1.0
                }
            }
        }

        // Фаза 3: Вращение (0.5-2.0 сек)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 1.5)) {
                rotationAngle = 360 * 3  // 3 полных оборота за 1.5 секунды
            }
        }

        // Финальный сброс через 2.0 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                rotationAngle = 0
                scale = 1.0
                offsetY = 0
            }
        }
    }
}

struct DiceDotsView: View {
    let value: Int

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let dotSize: CGFloat = 6
            let spacing: CGFloat = 8

            ZStack {
                // Точки в зависимости от значения
                switch value {
                case 1:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2, y: size.height / 2)

                case 2:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 + spacing)

                case 3:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2, y: size.height / 2)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 + spacing)

                case 4:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 + spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 + spacing)

                case 5:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2, y: size.height / 2)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 + spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 + spacing)

                case 6:
                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 - spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 - spacing, y: size.height / 2 + spacing)

                    Circle()
                        .fill(Color.black)
                        .frame(width: dotSize, height: dotSize)
                        .position(x: size.width / 2 + spacing, y: size.height / 2 + spacing)

                default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Helpers

// MARK: - ViewModel для экрана кубиков
@MainActor
class RaceDiceRollViewModel: ObservableObject {
    @Published var diceResults: [String: Int] = [:]

    func generateDiceResults(for participants: [RaceParticipant]) {
        diceResults.removeAll()

        for participant in participants {
            // Генерируем индивидуальное значение кубика для каждого участника
            let diceValue = Int.random(in: 1...6)
            diceResults[participant.id] = diceValue
            AppLogger.shared.debug(
                "Участник \(participant.user.name ?? participant.user.username ?? "Unknown") (id: \(participant.id)) получил: \(diceValue)", category: .ui)
        }

        AppLogger.shared.debug("Сгенерированы индивидуальные результаты кубиков: \(diceResults)", category: .ui)
    }
}

#Preview {
    // Создаем тестовые данные через JSON для корректной инициализации
    let participant1JSON = """
        {
            "id": "1",
            "raceId": "race1",
            "userId": "user1",
            "currentPosition": 0,
            "totalMoves": 0,
            "boostUsed": 0,
            "obstaclesHit": 0,
            "finalPosition": null,
            "prize": null,
            "isFinished": false,
            "joinedAt": "2024-01-01T00:00:00Z",
            "finishedAt": null,
            "user": {
                "id": "user1",
                "name": "Игрок 1",
                "username": "player1",
                "avatarUrl": null
            }
        }
        """.data(using: .utf8)!

    let participant2JSON = """
        {
            "id": "2",
            "raceId": "race1",
            "userId": "user2",
            "currentPosition": 0,
            "totalMoves": 0,
            "boostUsed": 0,
            "obstaclesHit": 0,
            "finalPosition": null,
            "prize": null,
            "isFinished": false,
            "joinedAt": "2024-01-01T00:00:00Z",
            "finishedAt": null,
            "user": {
                "id": "user2",
                "name": "Игрок 2",
                "username": "player2",
                "avatarUrl": null
            }
        }
        """.data(using: .utf8)!

    let participant1: RaceParticipant
    let participant2: RaceParticipant
    
    do {
        participant1 = try JSONDecoder().decode(RaceParticipant.self, from: participant1JSON)
        participant2 = try JSONDecoder().decode(RaceParticipant.self, from: participant2JSON)
    } catch {
        // В Preview используем fatalError, так как это только для разработки
        fatalError("Failed to decode RaceParticipant in Preview: \(error.localizedDescription)")
    }

    return RaceDiceRollView(
        participants: [participant1, participant2],
        initialDiceResults: [:],
        isInitiator: true,
        onNext: {},
        onDiceRollComplete: { _ in },
        onDismiss: {}
    )
}
