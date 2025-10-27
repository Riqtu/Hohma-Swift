import Inject
import SwiftUI

struct RaceDetailView: View {
    @ObserveInjection var inject
    let race: Race
    @ObservedObject var viewModel: RaceListViewModel
    @Environment(\.dismiss) private var dismiss
    let onNavigateToRaceList: (() -> Void)?

    @State private var showingDeleteAlert = false
    @State private var showingJoinAlert = false
    @State private var showingRaceScene = false

    init(race: Race, viewModel: RaceListViewModel, onNavigateToRaceList: (() -> Void)? = nil) {
        self.race = race
        self.viewModel = viewModel
        self.onNavigateToRaceList = onNavigateToRaceList
    }

    // Получаем актуальные данные скачки из viewModel
    private var currentRace: Race {
        viewModel.races.first { $0.id == race.id } ?? race
    }

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
            .navigationTitle(currentRace.name)
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
                                viewModel.startRace(raceId: currentRace.id)
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
                    viewModel.joinRace(raceId: currentRace.id) {
                        // После успешного присоединения переходим в скачку
                        showingRaceScene = true
                    }
                }
            } message: {
                Text("Взнос за участие: \(currentRace.entryFee) монет")
            }
            .alert("Удалить скачку", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    viewModel.deleteRace(raceId: currentRace.id)
                    dismiss()
                }
            } message: {
                Text("Это действие нельзя отменить")
            }
            .fullScreenCover(isPresented: $showingRaceScene) {
                NavigationView {
                    RaceSceneView(race: currentRace)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Назад") {
                                    showingRaceScene = false
                                }
                            }
                        }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
                    notification in
                    if let destination = notification.userInfo?["destination"] as? String,
                        destination == "race"
                    {
                        // Закрываем RaceSceneView и RaceDetailView, возвращаемся к списку гонок
                        showingRaceScene = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
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
                RaceStatusBadge(status: currentRace.status)
                Spacer()
                if currentRace.isPrivate {
                    Label("Приватная", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(currentRace.road.name)
                .font(.title2)
                .fontWeight(.semibold)

            HStack {
                Label(
                    "\(currentRace.participantCount ?? 0)/\(currentRace.maxPlayers) игроков",
                    systemImage: "person.2")
                Spacer()
                if currentRace.entryFee > 0 {
                    Label("\(currentRace.entryFee) монет", systemImage: "dollarsign.circle")
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
                    value: currentRace.creator.name ?? currentRace.creator.username ?? "Неизвестно")
                InfoRow(label: "Призовой фонд", value: "\(currentRace.prizePool) монет")
                InfoRow(label: "Создана", value: currentRace.createdAt.formattedDate)

                if let startTime = currentRace.startTime {
                    InfoRow(label: "Начата", value: startTime.formattedDate)
                }

                if let endTime = currentRace.endTime {
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

            if let participants = currentRace.participants, !participants.isEmpty {
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
                InfoRow(label: "Длина", value: "\(currentRace.road.length) клеток")
                InfoRow(label: "Сложность", value: currentRace.road.difficulty.displayName)
                InfoRow(label: "Тема", value: currentRace.road.theme)

                if let description = currentRace.road.description, !description.isEmpty {
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
            if let cells = currentRace.road.cells, !cells.isEmpty {
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
            if currentRace.status == .finished {
                // Гонка завершена - показываем кнопку "Посмотреть результаты"
                Button("Посмотреть результаты") {
                    showingRaceScene = true
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color("AccentColor"))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            } else if isCurrentUserParticipant {
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
                    viewModel.joinRace(raceId: currentRace.id) {
                        // После успешного присоединения переходим в скачку
                        showingRaceScene = true
                    }
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
                    viewModel.startRace(raceId: currentRace.id)
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
        currentRace.status == .created
            && (currentRace.participantCount ?? 0) < currentRace.maxPlayers
    }

    private var canStartRace: Bool {
        currentRace.status == .created && (currentRace.participantCount ?? 0) >= 2
    }

    private var canDeleteRace: Bool {
        currentRace.status == .created || currentRace.status == .cancelled
    }

    private var isCurrentUserParticipant: Bool {
        guard let currentUserId = viewModel.trpcService.currentUser?.id else { return false }
        return currentRace.participants?.contains { $0.userId == currentUserId } ?? false
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
