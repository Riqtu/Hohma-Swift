import Inject
import SwiftUI

struct RaceListView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = RaceListViewModel()
    @State private var showingFilters = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
                headerView

                // Content
                if viewModel.isLoading && viewModel.races.isEmpty {
                    loadingView
                } else if viewModel.filteredRaces.isEmpty {
                    emptyStateView
                } else {
                    raceListView
                }
            }
            .navigationTitle("Скачки")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $viewModel.showingRaceDetail) {
                if let race = viewModel.selectedRace {
                    RaceDetailView(race: race, viewModel: viewModel)
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .enableInjection()
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
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
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Race List View
    private var raceListView: some View {
        List {
            ForEach(viewModel.filteredRaces) { race in
                RaceCard(race: race) {
                    viewModel.showRaceDetail(race)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            viewModel.loadRaces()
        }
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
            .buttonStyle(.borderedProminent)
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
        .background(Color(.systemBackground))
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(race.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(race.road.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    RaceStatusBadge(status: race.status)
                }

                // Info
                HStack {
                    Label(
                        "\(race.participantCount ?? 0)/\(race.maxPlayers)", systemImage: "person.2"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    if race.entryFee > 0 {
                        Label("\(race.entryFee) монет", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if race.prizePool > 0 {
                        Label("\(race.prizePool) монет", systemImage: "trophy")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Creator
                HStack {
                    AsyncImage(url: URL(string: race.creator.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                    Text(race.creator.name ?? race.creator.username ?? "Неизвестно")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(race.createdAt.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
extension String {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        if let date = formatter.date(from: self) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return self
    }
}

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
