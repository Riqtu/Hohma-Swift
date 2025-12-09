//
//  StatsView.swift
//  Hohma
//
//  Created by Assistant on 27.11.2025.
//

import Inject
import SwiftUI

struct StatsView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = StatsViewModel()
    @State private var showingFilters = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with filters
            headerView

            // Content
            if viewModel.isLoading && viewModel.leaderboard.isEmpty {
                loadingView
            } else if viewModel.leaderboard.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // User stats card
                        if let userStats = viewModel.userStats {
                            userStatsCard(userStats)
                        }

                        // Leaderboard
                        leaderboardView
                    }
                    .padding()
                }
                .refreshable {
                    viewModel.loadLeaderboard()
                    viewModel.loadUserStats()
                }
            }
        }
        .appBackground()
        .navigationTitle("Статистика")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            StatsFiltersView(viewModel: viewModel)
        }
        .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.loadLeaderboard()
            viewModel.loadUserStats()
        }
        .enableInjection()
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Game type filter
                    Menu {
                        ForEach(GameType.allCases, id: \.self) { gameType in
                            Button(action: {
                                viewModel.selectedGameType = gameType
                                viewModel.applyFilters()
                            }) {
                                HStack {
                                    Text(gameType.displayName)
                                    if viewModel.selectedGameType == gameType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.selectedGameType.displayName)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    // Sort by filter
                    Menu {
                        ForEach(SortBy.allCases, id: \.self) { sortBy in
                            Button(action: {
                                viewModel.selectedSortBy = sortBy
                                viewModel.applyFilters()
                            }) {
                                HStack {
                                    Text(sortBy.displayName)
                                    if viewModel.selectedSortBy == sortBy {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.selectedSortBy.displayName)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color("AccentColor"))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - User Stats Card
    private func userStatsCard(_ stats: UserStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let avatarUrl = stats.user.avatarUrl, let url = URL(string: avatarUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(stats.user.displayName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.user.displayName)
                        .font(.headline)
                    Text("Ваша статистика")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Stats grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 16
            ) {
                StatsStatCard(
                    title: "Побед",
                    value: "\(stats.currentStats.wins)",
                    icon: "trophy.fill",
                    color: .yellow
                )

                StatsStatCard(
                    title: "Участий",
                    value: "\(stats.currentStats.participations)",
                    icon: "gamecontroller.fill",
                    color: .blue
                )

                StatsStatCard(
                    title: "Процент побед",
                    value: String(format: "%.1f%%", stats.currentStats.winRate),
                    icon: "percent",
                    color: .green
                )

                StatsStatCard(
                    title: "Призы",
                    value: "\(stats.currentStats.totalPrize)",
                    icon: "gift.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Leaderboard View
    private var leaderboardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Таблица лидеров")
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                LeaderboardRowView(
                    rank: index + 1,
                    entry: entry
                )
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Загрузка статистики...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Нет данных")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Статистика будет доступна после участия в играх")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stats Stat Card
struct StatsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Leaderboard Row View
struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 30)

            // Avatar
            if let avatarUrl = entry.user.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(entry.user.displayName.prefix(1)).uppercased())
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.user.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(
                    "\(entry.currentStats.wins) побед • \(entry.currentStats.participations) участий"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Win rate
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f%%", entry.currentStats.winRate))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("побед")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Stats Filters View
struct StatsFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        NavigationView {
            Form {
                Section("Тип игры") {
                    Picker("Тип игры", selection: $viewModel.selectedGameType) {
                        ForEach(GameType.allCases, id: \.self) { gameType in
                            Text(gameType.displayName).tag(gameType)
                        }
                    }
                }

                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.selectedSortBy) {
                        ForEach(SortBy.allCases, id: \.self) { sortBy in
                            Text(sortBy.displayName).tag(sortBy)
                        }
                    }
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Применить") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        StatsView()
    }
}
