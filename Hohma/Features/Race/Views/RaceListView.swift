import Inject
import SwiftUI

struct RaceListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceListViewModel()
    @State private var showingFilters = false
    @State private var raceToJoin: Race?
    @State private var raceToOpen: Race?
    @State private var raceToShowInfo: Race?
    @State private var raceToShare: Race?

    var body: some View {
        VStack(spacing: 0) {
            // Сегментированный контрол для фильтрации
            Picker("Фильтр", selection: $viewModel.selectedFilter) {
                Text("Все").tag(RaceFilterType.all)
                Text("Мои").tag(RaceFilterType.my)
                Text("Подписки").tag(RaceFilterType.following)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.selectedFilter) { oldValue, newValue in
                viewModel.loadRaces()
            }
            
            // Header with filters
            headerView

            // Content
            if viewModel.isLoading && viewModel.races.isEmpty {
                loadingView
            } else if viewModel.filteredRaces.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    raceListView
                }
                .refreshable {
                    viewModel.loadRaces()
                }
            }
        }
        .appBackground()
        .navigationTitle("Скачки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.showingCreateRace = true }) {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canCreateRace)
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCreateRace) {
            CreateRaceView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingFilters) {
            RaceFiltersView(viewModel: viewModel)
        }
        .sheet(item: $raceToJoin) { race in
            RaceJoinMovieView(race: race) { selection in
                viewModel.joinRace(raceId: race.id, movie: selection) {
                    raceToJoin = nil
                }
            }
        }
        .sheet(item: $raceToShowInfo) { race in
            RaceDetailView(race: race, viewModel: viewModel) {
                raceToShowInfo = nil
            }
        }
        .fullScreenCover(item: $raceToOpen) { race in
            NavigationView {
                RaceSceneView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Назад") {
                                raceToOpen = nil
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
                    raceToOpen = nil
                }
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $raceToShare) { race in
            ShareRaceToChatView(race: race) {
                raceToShare = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareRace)) { notification in
            if let race = notification.userInfo?["race"] as? Race {
                raceToShare = race
            }
        }
        .enableInjection()
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Stats cards
            HStack(spacing: 12) {
                RaceStatCard(
                    title: "Всего",
                    value: "\(viewModel.races.count)",
                    icon: "trophy.fill",
                    color: .blue
                )

                RaceStatCard(
                    title: "Активные",
                    value: "\(viewModel.activeRaces.count)",
                    icon: "play.circle.fill",
                    color: .green
                )

                RaceStatCard(
                    title: "Мои",
                    value: "\(viewModel.myRaces.count)",
                    icon: "person.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)

            // Quick filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Все",
                        isSelected: viewModel.selectedStatus == nil
                    ) {
                        viewModel.selectedStatus = nil
                        viewModel.applyFilters()
                    }

                    ForEach(
                        [RaceStatus.created, RaceStatus.running, RaceStatus.finished], id: \.self
                    ) { status in
                        FilterChip(
                            title: status.displayName,
                            isSelected: viewModel.selectedStatus == status
                        ) {
                            viewModel.selectedStatus = status
                            viewModel.applyFilters()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Race List View
    private var raceListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredRaces) { race in
                RaceCard(
                    race: race,
                    canJoin: canJoin(race),
                    onOpen: {
                        raceToOpen = race
                    },
                    onInfo: {
                        raceToShowInfo = race
                    },
                    onJoin: {
                        raceToJoin = race
                    }
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }

    private func canJoin(_ race: Race) -> Bool {
        let currentCount = race.participantCount ?? race.participants?.count ?? 0
        return (race.status == .created || race.status == .waiting)
            && currentCount < race.maxPlayers
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка скачек...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Скачки не найдены")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Создайте первую скачку или измените фильтры")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Создать скачку") {
                viewModel.showingCreateRace = true
            }

            .disabled(!viewModel.canCreateRace)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Card
struct RaceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color("AccentColor") : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Race Card
struct RaceCard: View {
    let race: Race
    let canJoin: Bool
    let onOpen: () -> Void
    let onInfo: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(race.name)
                        .font(.headline)
                    Text(race.road.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                RaceStatusBadge(status: race.status)
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        "\(race.participantCount ?? race.participants?.count ?? 0)/\(race.maxPlayers)",
                        systemImage: "person.3.fill"
                    )
                    .font(.caption)
                    Spacer()
                    if race.entryFee > 0 {
                        Label("\(race.entryFee) монет", systemImage: "dollarsign.circle")
                            .font(.caption)
                    }
                    if race.prizePool > 0 {
                        Label("\(race.prizePool) монет", systemImage: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.secondary)

                if race.status == .finished,
                    let winner = race.participants?.first(where: { $0.finalPosition == 1 })
                {
                    Label(
                        "🏆 \(winner.movieTitle ?? winner.user.name ?? winner.user.username ?? "Неизвестно")",
                        systemImage: "crown.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }

            HStack {
                CachedAsyncImage(url: URL(string: race.creator.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text(race.creator.name ?? race.creator.username ?? "Неизвестно")
                        .font(.caption)
                    Text(race.createdAt.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundColor(Color("AccentColor"))
            }

            if canJoin {
                Button(action: onJoin) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Добавить фильм в скачку")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderless)

                .background(Color("AccentColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
        .contextMenu {
            Button {
                NotificationCenter.default.post(
                    name: .shareRace,
                    object: nil,
                    userInfo: ["race": race]
                )
            } label: {
                Label("Поделиться в чате", systemImage: "arrow.up.right.square")
            }
        }
    }
}

// MARK: - Status Badge
struct RaceStatusBadge: View {
    let status: RaceStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

// MARK: - Extensions
// formattedDate extension уже определен в другом месте

extension RaceStatus {
    var color: Color {
        switch self {
        case .created: return .blue
        case .waiting: return .yellow
        case .running: return .green
        case .finished: return .gray
        case .cancelled: return .red
        }
    }
}

#Preview {
    RaceListView()
}
