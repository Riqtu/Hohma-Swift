import Inject
import SwiftUI

struct WinnerSelectionView: View {
    @ObserveInjection var inject
    @Binding var isPresented: Bool
    let finishingParticipants: [String]
    let participants: [RaceParticipant]
    let winnerId: String?  // Победитель уже определен сервером
    let onWinnerSelected: (String) -> Void

    @State private var selectedWinner: String?
    @State private var isAnimating: Bool = false
    @State private var animationProgress: Double = 0.0
    @State private var isSelecting: Bool = false  // Флаг процесса выбора

    var body: some View {
        ZStack {
            // Полупрозрачный фон
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Заголовок
                Text("Финиш!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Несколько участников финишировали одновременно")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                if winnerId != nil {
                    Text("Определяем победителя...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                // Список финишировавших участников
                VStack(spacing: 12) {
                    ForEach(finishingParticipants, id: \.self) { participantId in
                        if let participant = participants.first(where: { $0.id == participantId }) {
                            ParticipantCard(
                                participant: participant,
                                isSelected: selectedWinner == participantId || (isSelecting && winnerId == participantId),
                                isAnimating: isAnimating && selectedWinner == participantId
                            )
                            .onTapGesture {
                                // Разрешаем выбор только если победитель еще не определен сервером
                                if winnerId == nil {
                                    selectWinner(participantId)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Кнопка выбора победителя (только для визуализации, если победитель уже определен)
                if winnerId == nil {
                    Button(action: {
                        if let winner = selectedWinner {
                            selectWinnerWithAnimation(winner)
                        }
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Выбрать победителя")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            selectedWinner != nil ? Color("AccentColor") : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(selectedWinner == nil)
                    .padding(.horizontal)

                    // Информация о случайном выборе
                    Text("Победитель будет выбран случайно")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("AccentColor"), lineWidth: 2)
                    )
            )
            .padding()
        }
        .onAppear {
            // Если победитель уже определен сервером, показываем анимацию выбора
            if let winner = winnerId {
                // Небольшая задержка для визуального эффекта
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Показываем анимацию "выбора" всех участников
                    isSelecting = true
                    
                    // Через 1.5 секунды "выбираем" победителя
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        selectWinnerWithAnimation(winner)
                    }
                }
            } else {
                // Если победитель не определен, выбираем случайного через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if selectedWinner == nil {
                        let randomWinner =
                            finishingParticipants.randomElement() ?? finishingParticipants[0]
                        selectWinnerWithAnimation(randomWinner)
                    }
                }
            }
        }
        .enableInjection()
    }

    private func selectWinner(_ participantId: String) {
        selectedWinner = participantId

        // Тактильная обратная связь
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func selectWinnerWithAnimation(_ winnerId: String) {
        selectedWinner = winnerId
        isAnimating = true

        // Анимация выбора победителя
        withAnimation(.easeInOut(duration: 1.0)) {
            animationProgress = 1.0
        }

        // Задержка перед закрытием экрана
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onWinnerSelected(winnerId)
            isPresented = false
        }
    }
}

struct ParticipantCard: View {
    let participant: RaceParticipant
    let isSelected: Bool
    let isAnimating: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Аватар
            AsyncImage(url: URL(string: participant.user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Text(
                            String(
                                participant.user.name?.first ?? participant.user.username?.first
                                    ?? "?")
                        )
                        .font(.headline)
                        .foregroundColor(.white)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // Информация об участнике
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.user.name ?? participant.user.username ?? "Неизвестно")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(participant.totalMoves) ходов")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Индикатор выбора
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color("AccentColor"))
                    .font(.title2)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: isAnimating)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.title2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color("AccentColor").opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color("AccentColor") : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    let participant1Data = """
            {
                "id": "1",
                "raceId": "race1",
                "userId": "user1",
                "currentPosition": 10,
                "totalMoves": 5,
                "boostUsed": 1,
                "obstaclesHit": 0,
                "finalPosition": null,
                "prize": null,
                "isFinished": true,
                "joinedAt": "2024-01-01T00:00:00Z",
                "finishedAt": "2024-01-01T00:05:00Z",
                "user": {
                    "id": "user1",
                    "name": "Игрок 1",
                    "username": "player1",
                    "avatarUrl": null
                }
            }
        """.data(using: .utf8)!

    let participant2Data = """
            {
                "id": "2",
                "raceId": "race1",
                "userId": "user2",
                "currentPosition": 10,
                "totalMoves": 6,
                "boostUsed": 0,
                "obstaclesHit": 1,
                "finalPosition": null,
                "prize": null,
                "isFinished": true,
                "joinedAt": "2024-01-01T00:00:00Z",
                "finishedAt": "2024-01-01T00:05:00Z",
                "user": {
                    "id": "user2",
                    "name": "Игрок 2",
                    "username": "player2",
                    "avatarUrl": null
                }
            }
        """.data(using: .utf8)!

    let participant1 = try! JSONDecoder().decode(RaceParticipant.self, from: participant1Data)
    let participant2 = try! JSONDecoder().decode(RaceParticipant.self, from: participant2Data)

    return WinnerSelectionView(
        isPresented: .constant(true),
        finishingParticipants: ["1", "2"],
        participants: [participant1, participant2],
        winnerId: nil,
        onWinnerSelected: { _ in }
    )
    .background(Color.black)
}
