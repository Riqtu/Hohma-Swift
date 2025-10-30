import Inject
import SwiftUI

struct RaceDiceRollView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceDiceRollViewModel()
    let participants: [RaceParticipant]
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
                    LazyVStack(spacing: 20) {
                        ForEach(Array(participants.enumerated()), id: \.element.id) {
                            index, participant in
                            ParticipantDiceRow(
                                participant: participant,
                                diceValue: viewModel.diceResults[participant.id] ?? 0,
                                isAnimating: isAnimating,
                                animationDelay: Double(index) * 0.2
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 400)

                // Кнопка "Дальше"
                if showContinueButton {
                    Button(action: {
                        onDiceRollComplete(viewModel.diceResults)
                        onDismiss()
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
            startDiceAnimation()
        }
        .enableInjection()
    }

    private func startDiceAnimation() {
        // Генерируем случайные значения кубиков для всех участников
        viewModel.generateDiceResults(for: participants)

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
        HStack(spacing: 20) {
            // Аватар участника
            AsyncImage(url: URL(string: participant.user.avatarUrl ?? "")) { image in
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

            // Имя участника и статус
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.user.name ?? participant.user.username ?? "Неизвестно")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Позиция: \(participant.currentPosition)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                // Показываем только эффекты пропуска хода (красные поля)
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

            // Кубик
            DiceView(
                value: currentDiceValue,
                isAnimating: isAnimating,  // Используем isAnimating из родительского компонента
                animationDelay: animationDelay,
                skipNextTurn: participant.skipNextTurn
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(participantBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(participantBorderColor, lineWidth: 2)
                )
        )
        .onAppear {
            if isAnimating && !hasStartedAnimation {
                startDiceAnimation()
            }
        }
        .onChange(of: isAnimating) {
            if isAnimating && !hasStartedAnimation {
                startDiceAnimation()
            }
        }
    }

    // MARK: - Computed Properties
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
                .frame(width: 60, height: 60)
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
        .onChange(of: isAnimating) {
            if isAnimating && !hasAnimated {
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
            let dotSize: CGFloat = 8
            let spacing: CGFloat = 12

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
            print(
                "🎲 Участник \(participant.user.name ?? participant.user.username ?? "Unknown") (id: \(participant.id)) получил: \(diceValue)"
            )
        }

        print("🎲 Сгенерированы индивидуальные результаты кубиков: \(diceResults)")
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

    let participant1 = try! JSONDecoder().decode(RaceParticipant.self, from: participant1JSON)
    let participant2 = try! JSONDecoder().decode(RaceParticipant.self, from: participant2JSON)

    return RaceDiceRollView(
        participants: [participant1, participant2],
        onDiceRollComplete: { _ in },
        onDismiss: {}
    )
}
