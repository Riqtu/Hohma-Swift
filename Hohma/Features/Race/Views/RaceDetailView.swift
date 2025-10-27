import Inject
import SwiftUI

struct RaceDetailView: View {
    @ObserveInjection var inject
    let race: Race
    @ObservedObject var viewModel: RaceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteAlert = false
    @State private var showingJoinAlert = false
    @State private var showingRaceScene = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Race Info
                    raceInfoSection

                    // Participants
                    participantsSection

                    // Road Preview
                    roadPreviewSection

                    // Actions
                    actionsSection
                }
                .padding()
            }
            .appBackground()
            .navigationTitle(race.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isCurrentUserParticipant {
                            Button("Вход в скачку") {
                                showingRaceScene = true
                            }
                        } else if canJoinRace {
                            Button("Присоединиться") {
                                showingJoinAlert = true
                            }
                        }

                        if canStartRace {
                            Button("Начать скачку") {
                                viewModel.startRace(raceId: race.id)
                                showingRaceScene = true
                            }
                        }

                        if canDeleteRace {
                            Button("Удалить", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Присоединиться к скачке", isPresented: $showingJoinAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Присоединиться") {
                    viewModel.joinRace(raceId: race.id)
                }
            } message: {
                Text("Взнос за участие: \(race.entryFee) монет")
            }
            .alert("Удалить скачку", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    viewModel.deleteRace(raceId: race.id)
                    dismiss()
                }
            } message: {
                Text("Это действие нельзя отменить")
            }
            .fullScreenCover(isPresented: $showingRaceScene) {
                NavigationView {
                    RaceSceneView(race: race)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Назад") {
                                    showingRaceScene = false
                                }
                            }
                        }
                }
            }
        }
        .enableInjection()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RaceStatusBadge(status: race.status)
                Spacer()
                if race.isPrivate {
                    Label("Приватная", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(race.road.name)
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                Label(
                    "\(race.participantCount ?? 0)/\(race.maxPlayers) игроков",
                    systemImage: "person.2")
                Spacer()
                if race.entryFee > 0 {
                    Label("\(race.entryFee) монет", systemImage: "dollarsign.circle")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Race Info Section
    private var raceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Информация о скачке")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(
                    label: "Создатель",
                    value: race.creator.name ?? race.creator.username ?? "Неизвестно")
                InfoRow(label: "Призовой фонд", value: "\(race.prizePool) монет")
                InfoRow(label: "Создана", value: race.createdAt.formattedDate)

                if let startTime = race.startTime {
                    InfoRow(label: "Начата", value: startTime.formattedDate)
                }

                if let endTime = race.endTime {
                    InfoRow(label: "Завершена", value: endTime.formattedDate)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Participants Section
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Участники")
                .font(.headline)

            if let participants = race.participants, !participants.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(participants) { participant in
                        ParticipantRow(participant: participant)
                    }
                }
            } else {
                Text("Нет участников")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Road Preview Section
    private var roadPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Дорога")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(label: "Длина", value: "\(race.road.length) клеток")
                InfoRow(label: "Сложность", value: race.road.difficulty.displayName)
                InfoRow(label: "Тема", value: race.road.theme)

                if let description = race.road.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Описание")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Road cells preview
            if let cells = race.road.cells, !cells.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(cells.prefix(20)) { cell in
                            CellPreview(cell: cell)
                        }

                        if cells.count > 20 {
                            Text("...")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Text("Клетки дороги не загружены")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if isCurrentUserParticipant {
                // Пользователь уже участник - показываем кнопку "Вход"
                Button("Вход в скачку") {
                    showingRaceScene = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("AccentColor"))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            } else if canJoinRace {
                // Пользователь может присоединиться
                Button("Присоединиться к скачке") {
                    showingJoinAlert = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("AccentColor"))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }

            if canStartRace {
                Button("Начать скачку") {
                    viewModel.startRace(raceId: race.id)
                    showingRaceScene = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("AccentColor"))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Computed Properties
    private var canJoinRace: Bool {
        race.status == .created && (race.participantCount ?? 0) < race.maxPlayers
    }

    private var canStartRace: Bool {
        race.status == .created && (race.participantCount ?? 0) >= 2
    }

    private var canDeleteRace: Bool {
        race.status == .created || race.status == .cancelled
    }

    private var isCurrentUserParticipant: Bool {
        guard let currentUserId = viewModel.trpcService.currentUser?.id else { return false }
        return race.participants?.contains { $0.userId == currentUserId } ?? false
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Participant Row
struct ParticipantRow: View {
    let participant: RaceParticipant

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: participant.user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.user.name ?? participant.user.username ?? "Неизвестно")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Позиция: \(participant.currentPosition)")
                    if participant.isFinished {
                        Text("• Финишировал")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if let finalPosition = participant.finalPosition {
                Text("#\(finalPosition)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cell Preview
struct CellPreview: View {
    let cell: RoadCell

    var body: some View {
        Rectangle()
            .fill(cell.cellType.color.opacity(0.3))
            .frame(width: 20, height: 20)
            .cornerRadius(4)
            .overlay(
                Text("\(cell.position)")
                    .font(.caption2)
                    .fontWeight(.bold)
            )
    }
}

extension CellType {
    var color: Color {
        switch self {
        case .normal: return .gray
        case .boost: return .green
        case .obstacle: return .red
        case .bonus: return .blue
        case .finish: return .yellow
        }
    }
}
