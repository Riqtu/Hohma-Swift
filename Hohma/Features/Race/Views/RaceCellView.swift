import Inject
import SwiftUI

struct RaceCellView: View {
    @ObserveInjection var inject
    let cellData: RaceCellData
    let participant: RaceParticipant
    let isAnimating: Bool
    let animationProgress: Double
    let previousPosition: Int?

    // Новые параметры для пошаговой анимации
    let currentStepPosition: Double?
    let isJumping: Bool
    let animationStepProgress: Double?

    var body: some View {
        ZStack {
            cellBackground
            cellIcon
            participantView
        }
        .padding(5)
        .padding(.horizontal, 5)
        .padding(.vertical, 15)
        .zIndex(cellData.position == participant.currentPosition ? 5 : 1)
        .enableInjection()
    }

    // MARK: - UI Components
    private var cellBackground: some View {
        Rectangle()
            .fill(cellBackgroundColor)
            .frame(width: 25, height: 25)
            .cornerRadius(5)
            .shadow(
                color: shouldShowParticipant && isAnimating
                    ? .blue.opacity(0.4) : Color.black.opacity(0.1),
                radius: shouldShowParticipant && isAnimating ? 8 : 5,
                x: 0,
                y: shouldShowParticipant && isAnimating ? 3 : 2
            )
            .overlay(cellEffectOverlay)

    }

    private var cellIcon: some View {
        Group {
            if cellData.type != .normal {
                Image(systemName: cellTypeIcon)
                    .font(.caption)
                    .foregroundColor(cellTypeColor)
                    .scaleEffect(shouldShowParticipant && isAnimating ? 1.2 : 1.0)

            }
        }
    }

    private var participantView: some View {
        Group {
            if shouldShowParticipant {
                participantAvatar
            }
        }
    }

    private var participantAvatar: some View {
        Group {
            if showPoster {
                posterView
                    .opacity(participantOpacity)
                    .offset(x: participantOffsetX, y: participantOffsetY)
            } else {
                ZStack {
                    participantBackground
                    avatarImage
                }
                .padding(.bottom, 50)
                .overlay(participantBorder)
                .padding(.horizontal, -25)
                .zIndex(10)
                .scaleEffect(shouldShowParticipant && (isAnimating || isJumping) ? 1.2 : 1.0)
                .opacity(participantOpacity)
                .rotationEffect(.degrees(shouldShowParticipant && isJumping ? 15 : 0))
                .offset(x: participantOffsetX, y: participantOffsetY)
                .animation(.easeInOut(duration: 0.2), value: shouldShowParticipant)
                .animation(.easeInOut(duration: 0.2), value: isAnimating)
                .animation(.easeInOut(duration: 0.2), value: isJumping)
                .animation(.easeInOut(duration: 0.2), value: animationProgress)
            }
        }
    }

    private var showPoster: Bool {
        if let poster = participant.moviePosterUrl {
            return !poster.isEmpty
        }
        return false
    }

    private var posterView: some View {
        RacePosterView(
            posterUrl: participant.moviePosterUrl ?? "",
            title: participant.movieTitle,
            width: 55,
            height: 80,
            showTitle: true
        )
        .padding(.bottom, 45)
        .padding(.horizontal, -25)
        .zIndex(10)
        .scaleEffect(shouldShowParticipant && (isAnimating || isJumping) ? 1.05 : 1.0)
        .opacity(participantOpacity)
        .rotationEffect(.degrees(shouldShowParticipant && isJumping ? 10 : 0))
        .offset(x: participantOffsetX, y: participantOffsetY - 10)
        .animation(.easeInOut(duration: 0.2), value: shouldShowParticipant)
        .animation(.easeInOut(duration: 0.2), value: isAnimating)
        .animation(.easeInOut(duration: 0.2), value: isJumping)
        .animation(.easeInOut(duration: 0.2), value: animationProgress)
    }

    private var participantBackground: some View {
        Circle()
            .fill(participant.isFinished ? .green : .blue)
            .frame(width: 60, height: 60)
            .shadow(
                color: shouldShowParticipant && isAnimating
                    ? .blue.opacity(0.6) : .black.opacity(0.3),
                radius: shouldShowParticipant && isAnimating ? 8 : 4,
                x: 0,
                y: shouldShowParticipant && isAnimating ? 4 : 2
            )
            .overlay(!showPoster ? pulsingEffect : nil)

    }

    private var avatarImage: some View {
        Group {
            if let avatarUrl = participant.user.avatarUrl, !avatarUrl.isEmpty {
                RaceAvatarView(
                    participant: participant,
                    size: 56,
                    showBorder: true,
                    borderColor: .white
                )
            } else {
                participantInitialsView
            }
        }
    }

    private var participantInitialsView: some View {
        ZStack {
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 56, height: 56)

            Text(participantInitials)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var pulsingEffect: some View {
        Group {
            if !participant.isFinished && shouldShowParticipant {
                Circle()
                    .stroke(participant.isFinished ? .green : .blue, lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .opacity(0.6)
                    .scaleEffect(shouldShowParticipant && isAnimating ? 1.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: shouldShowParticipant && isAnimating)
            }
        }
    }

    private var participantBorder: some View {
        Circle()
            .stroke(.white, lineWidth: 2)
            .padding(.bottom, 50)
    }

    // MARK: - Computed Properties
    private var shouldShowParticipant: Bool {
        // Если идет пошаговая анимация с дискретными позициями
        if let stepPosition = currentStepPosition {
            // Показываем участника только на точной позиции
            let shouldShow = cellData.position == Int(stepPosition)
            if shouldShow {
                AppLogger.shared.debug(
                    "Клетка \(cellData.position): показываем участника на позиции \(stepPosition)", category: .ui)
            }
            return shouldShow
        }

        // Если не идет анимация, показываем участника на его текущей позиции
        if !isAnimating {
            let shouldShow = cellData.position == participant.currentPosition
            if shouldShow {
                AppLogger.shared.debug("📍 Клетка \(cellData.position): показываем участника (не анимируется)", category: .ui)
            }
            return shouldShow
        }

        // Fallback к старой логике для совместимости
        if let previousPos = previousPosition {
            let currentPos = participant.currentPosition
            let totalDistance = currentPos - previousPos

            if totalDistance == 0 {
                return cellData.position == currentPos
            }

            let currentAnimationPosition =
                previousPos + Int(Double(totalDistance) * animationProgress)
            return cellData.position == currentAnimationPosition
        }

        return false
    }

    private var participantOpacity: Double {
        // Если идет пошаговая анимация с дискретными позициями
        if let stepPosition = currentStepPosition {
            // Участник полностью виден только на точной позиции
            return cellData.position == Int(stepPosition) ? 1.0 : 0.0
        }

        // Если не идет анимация, показываем участника полностью
        if !isAnimating {
            return cellData.position == participant.currentPosition ? 1.0 : 0.0
        }

        // Fallback к старой логике
        if let previousPos = previousPosition {
            let currentPos = participant.currentPosition
            let totalDistance = currentPos - previousPos

            if totalDistance == 0 {
                return cellData.position == currentPos ? 1.0 : 0.0
            }

            let currentAnimationPosition =
                previousPos + Int(Double(totalDistance) * animationProgress)
            return cellData.position == currentAnimationPosition ? 1.0 : 0.0
        }

        return 0.0
    }

    private var participantOffsetX: CGFloat {
        // Если участник прыгает, добавляем небольшое горизонтальное смещение
        if isJumping && shouldShowParticipant {
            return CGFloat.random(in: -2...2)
        }

        // Fallback к старой логике
        guard isAnimating, let previousPos = previousPosition else { return 0 }

        let currentPos = participant.currentPosition
        let totalDistance = currentPos - previousPos

        if totalDistance == 0 { return 0 }

        let animationProgress = self.animationProgress
        let currentAnimationPosition = previousPos + Int(Double(totalDistance) * animationProgress)

        if cellData.position == currentAnimationPosition {
            let randomOffset = sin(animationProgress * .pi * 4) * 2
            return randomOffset
        }

        return 0
    }

    private var participantOffsetY: CGFloat {
        // Если участник прыгает, создаем эффект прыжка
        if isJumping && shouldShowParticipant {
            return -15  // Высокий прыжок
        }

        // Fallback к старой логике
        guard isAnimating, let previousPos = previousPosition else { return 0 }

        let currentPos = participant.currentPosition
        let totalDistance = currentPos - previousPos

        if totalDistance == 0 { return 0 }

        let animationProgress = self.animationProgress
        let currentAnimationPosition = previousPos + Int(Double(totalDistance) * animationProgress)

        if cellData.position == currentAnimationPosition {
            let jumpHeight = sin(animationProgress * .pi) * 3
            return -jumpHeight
        }

        return 0
    }

    private var participantInitials: String {
        let name =
            participant.movieTitle ?? participant.user.name ?? participant.user.username ?? "U"
        let components = name.components(separatedBy: " ")

        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let secondInitial = String(components[1].prefix(1)).uppercased()
            return firstInitial + secondInitial
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    private var cellBackgroundColor: Color {
        if cellData.position == participant.currentPosition {
            return .blue.opacity(0.3)
        }

        // Подсвечиваем клетки, через которые проходит участник во время анимации
        if isAnimating, let previousPos = previousPosition {
            let currentPos = participant.currentPosition
            let totalDistance = currentPos - previousPos

            if totalDistance != 0 {
                let animationProgress = self.animationProgress
                let currentAnimationPosition =
                    previousPos + Int(Double(totalDistance) * animationProgress)

                if cellData.position == currentAnimationPosition {
                    return .blue.opacity(0.2)
                }
            }
        }

        // Специальные эффекты для полей с новыми механиками
        switch cellData.type {
        case .normal:
            return .gray.opacity(0.9)
        case .boost:
            // Зеленое поле с эффектом "ускорения"
            return .green.opacity(0.4)
        case .obstacle:
            // Красное поле с эффектом "препятствия"
            return .red.opacity(0.4)
        case .bonus:
            return .yellow.opacity(0.3)
        case .finish:
            return .purple.opacity(0.3)
        }
    }

    private var cellTypeIcon: String {
        switch cellData.type {
        case .normal:
            return ""
        case .boost:
            return "arrow.up"
        case .obstacle:
            return "exclamationmark.triangle"
        case .bonus:
            return "star"
        case .finish:
            return "flag"
        }
    }

    private var cellTypeColor: Color {
        switch cellData.type {
        case .normal:
            return .clear
        case .boost:
            return .green
        case .obstacle:
            return .red
        case .bonus:
            return .yellow
        case .finish:
            return .purple
        }
    }

    // MARK: - Special Effects
    private var cellEffectOverlay: some View {
        Group {
            switch cellData.type {
            case .boost:
                // Анимированное свечение для зеленого поля
                Rectangle()
                    .fill(.green.opacity(0.3))
                    .frame(width: 25, height: 25)
                    .cornerRadius(5)
                    .scaleEffect(1.0)
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: UUID()  // Запускаем анимацию при создании
                    )
            case .obstacle:
                // Пульсирующий эффект для красного поля
                Rectangle()
                    .fill(.red.opacity(0.2))
                    .frame(width: 25, height: 25)
                    .cornerRadius(5)
                    .scaleEffect(1.1)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: UUID()  // Запускаем анимацию при создании
                    )
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    let cellData = RaceCellData(
        position: 0,
        isActive: true,
        type: .normal,
        participants: []
    )

    // Создаем RaceParticipant из JSON для preview
    let jsonData = """
        {
            "id": "1",
            "raceId": "1",
            "userId": "1",
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
                "id": "1",
                "name": "Test",
                "username": "test",
                "avatarUrl": null
            }
        }
        """.data(using: .utf8)!

    let participant: RaceParticipant
    do {
        participant = try JSONDecoder().decode(RaceParticipant.self, from: jsonData)
    } catch {
        // В Preview используем fatalError, так как это только для разработки
        fatalError("Failed to decode RaceParticipant in Preview: \(error.localizedDescription)")
    }

    return RaceCellView(
        cellData: cellData,
        participant: participant,
        isAnimating: false,
        animationProgress: 0.0,
        previousPosition: nil,
        currentStepPosition: nil,
        isJumping: false,
        animationStepProgress: nil
    )
}
