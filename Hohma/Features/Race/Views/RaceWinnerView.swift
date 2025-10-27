import Inject
import SwiftUI

struct RaceWinnerView: View {
    @ObserveInjection var inject
    @Binding var isPresented: Bool
    let winner: RaceParticipant
    let race: Race
    let onDismiss: () -> Void
    let onNavigateToRaceList: (() -> Void)?

    init(
        isPresented: Binding<Bool>, winner: RaceParticipant, race: Race,
        onDismiss: @escaping () -> Void, onNavigateToRaceList: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.winner = winner
        self.race = race
        self.onDismiss = onDismiss
        self.onNavigateToRaceList = onNavigateToRaceList
    }

    @State private var isAnimating: Bool = false
    @State private var confettiAnimation: Bool = false

    var body: some View {
        ZStack {
            // Фон с эффектом конфетти
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            if confettiAnimation {
                ConfettiView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 30) {
                Spacer()

                // Корона победителя
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .rotationEffect(.degrees(isAnimating ? 10 : -10))
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isAnimating)

                // Заголовок
                Text("Победитель!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Информация о победителе
                VStack(spacing: 16) {
                    // Аватар победителя
                    AsyncImage(url: URL(string: winner.user.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(
                                    String(
                                        winner.user.name?.first ?? winner.user.username?.first
                                            ?? "?")
                                )
                                .font(.title)
                                .foregroundColor(.white)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 4)
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isAnimating)

                    // Имя победителя
                    Text(winner.user.name ?? winner.user.username ?? "Неизвестно")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Статистика победителя
                    VStack(spacing: 8) {
                        StatRow(title: "Ходов", value: "\(winner.totalMoves)")
                        StatRow(title: "Ускорений", value: "\(winner.boostUsed)")
                        StatRow(title: "Препятствий", value: "\(winner.obstaclesHit)")
                        if let prize = winner.prize, prize > 0 {
                            StatRow(title: "Выигрыш", value: "\(prize) монет", isPrize: true)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("AccentColor"), lineWidth: 1)
                            )
                    )
                }

                Spacer()

                // Кнопки действий
                VStack(spacing: 12) {
                    Button(action: {
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Назад")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AccentColor"))
                        .cornerRadius(12)
                    }

                    Button(action: {
                        // Выход к списку гонок
                        if let navigateToRaceList = onNavigateToRaceList {
                            navigateToRaceList()
                        } else {
                            // Fallback: отправляем уведомление о навигации
                            NotificationCenter.default.post(
                                name: .navigationRequested,
                                object: nil,
                                userInfo: ["destination": "race", "force": true]
                            )
                        }
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("К списку гонок")
                        }
                        .font(.headline)
                        .foregroundColor(Color("AccentColor"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("AccentColor"), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            startAnimations()
        }
        .enableInjection()
    }

    private func startAnimations() {
        // Запускаем анимацию корона и аватара
        isAnimating = true

        // Запускаем конфетти через небольшую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            confettiAnimation = true
        }

        // Останавливаем конфетти через 3 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            confettiAnimation = false
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let isPrize: Bool

    init(title: String, value: String, isPrize: Bool = false) {
        self.title = title
        self.value = value
        self.isPrize = isPrize
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(isPrize ? .yellow : .white)
        }
        .font(.subheadline)
    }
}

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            ForEach(confettiPieces, id: \.id) { piece in
                Rectangle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .position(piece.position)
                    .rotationEffect(.degrees(piece.rotation))
                    .opacity(piece.opacity)
            }
        }
        .onAppear {
            generateConfetti()
            animateConfetti()
        }
    }

    private func generateConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]

        for _ in 0..<50 {
            let piece = ConfettiPiece(
                id: UUID(),
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: -20
                ),
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 4...8),
                rotation: Double.random(in: 0...360),
                opacity: Double.random(in: 0.7...1.0)
            )
            confettiPieces.append(piece)
        }
    }

    private func animateConfetti() {
        withAnimation(.linear(duration: 3.0)) {
            for i in confettiPieces.indices {
                confettiPieces[i].position.y = UIScreen.main.bounds.height + 50
                confettiPieces[i].rotation += 360
                confettiPieces[i].opacity = 0
            }
        }
    }
}

struct ConfettiPiece {
    let id: UUID
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var rotation: Double
    var opacity: Double
}

#Preview {
    let winnerData = """
            {
                "id": "1",
                "raceId": "race1",
                "userId": "user1",
                "currentPosition": 10,
                "totalMoves": 5,
                "boostUsed": 1,
                "obstaclesHit": 0,
                "finalPosition": 1,
                "prize": 100,
                "isFinished": true,
                "joinedAt": "2024-01-01T00:00:00Z",
                "finishedAt": "2024-01-01T00:05:00Z",
                "user": {
                    "id": "user1",
                    "name": "Победитель",
                    "username": "winner",
                    "avatarUrl": null
                }
            }
        """.data(using: .utf8)!

    let raceData = """
            {
                "id": "race1",
                "name": "Тестовая гонка",
                "status": "FINISHED",
                "isPrivate": false,
                "theme": "default",
                "maxPlayers": 4,
                "entryFee": 10,
                "prizePool": 100,
                "startTime": null,
                "endTime": "2024-01-01T00:05:00Z",
                "createdAt": "2024-01-01T00:00:00Z",
                "updatedAt": "2024-01-01T00:05:00Z",
                "road": {
                    "id": "road1",
                    "name": "Тестовая дорога",
                    "description": null,
                    "theme": "default",
                    "length": 10,
                    "difficulty": "EASY",
                    "isActive": true,
                    "createdAt": "2024-01-01T00:00:00Z",
                    "updatedAt": "2024-01-01T00:00:00Z",
                    "cells": null,
                    "_count": null
                },
                "creator": {
                    "id": "creator1",
                    "name": "Создатель",
                    "username": "creator",
                    "avatarUrl": null
                },
                "participants": null,
                "_count": null
            }
        """.data(using: .utf8)!

    let winner = try! JSONDecoder().decode(RaceParticipant.self, from: winnerData)
    let race = try! JSONDecoder().decode(Race.self, from: raceData)

    return RaceWinnerView(
        isPresented: .constant(true),
        winner: winner,
        race: race,
        onDismiss: {},
        onNavigateToRaceList: nil
    )
}
