//
//  SubscriptionManagementView.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import SwiftUI
import Inject

struct SubscriptionManagementView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Заголовок
                HStack {
                    Text("Подписки")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
                .background(.thickMaterial)

                // Переключатель вкладок
                Picker("", selection: $selectedTab) {
                    Text("Подписки").tag(0)
                    Text("Подписчики").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 16)

                // Контент
                TabView(selection: $selectedTab) {
                    // Вкладка "Подписки"
                    FollowingListView(viewModel: viewModel)
                        .tag(0)

                    // Вкладка "Подписчики"
                    FollowersListView(viewModel: viewModel)
                        .tag(1)
                }
                .padding(.horizontal, 20)

                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .onAppear {
                Task {
                    await viewModel.loadFollowing()
                    await viewModel.loadFollowers()
                }
            }
            .refreshable {
                Task {
                    await viewModel.refreshFollowing()
                    await viewModel.refreshFollowers()
                }
            }
            .appBackground()
        }
    }
}

struct FollowingListView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: SubscriptionViewModel

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Загрузка подписок...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else if viewModel.following.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("Нет подписок")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    Text("Начните подписываться на других пользователей")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.following) { user in
                        UserProfileRow(
                            user: user,
                            isFollowing: true,
                            onFollowToggle: {
                                Task {
                                    let success = await viewModel.unfollowUser(followingId: user.id)
                                    if success {
                                        await viewModel.loadFollowing()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }

    }
}

struct FollowersListView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: SubscriptionViewModel

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Загрузка подписчиков...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else if viewModel.followers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)

                    Text("Нет подписчиков")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    Text("Поделитесь своими колесами, чтобы привлечь подписчиков")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 50)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.followers) { user in
                        UserProfileRow(
                            user: user,
                            isFollowing: false,
                            onFollowToggle: {
                                Task {
                                    let success = await viewModel.followUser(followingId: user.id)
                                    if success {
                                        await viewModel.loadFollowing()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }
}

struct UserProfileRow: View {
    @ObserveInjection var inject
    let user: UserProfile
    let isFollowing: Bool
    let onFollowToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Аватар
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }

            // Информация о пользователе
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name ?? user.username ?? "Пользователь")
                    .font(.headline)
                    .foregroundColor(.primary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Кнопка подписки/отписки
            Button(action: onFollowToggle) {
                Text(isFollowing ? "Отписаться" : "Подписаться")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isFollowing ? .red : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFollowing ? Color.red.opacity(0.1) : Color.accentColor)
                    )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    SubscriptionManagementView()
}
