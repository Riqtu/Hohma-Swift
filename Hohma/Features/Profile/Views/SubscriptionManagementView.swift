//
//  SubscriptionManagementView.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Inject
import SwiftUI

struct SubscriptionManagementView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Переключатель вкладок
                Picker("", selection: $selectedTab) {
                    Text("Подписки").tag(0)
                    Text("Подписчики").tag(1)
                    Text("Поиск").tag(2)
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

                    // Вкладка "Поиск"
                    UserSearchView(viewModel: viewModel)
                        .tag(2)
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
        .navigationTitle("Подписки")
        .navigationBarTitleDisplayMode(.large)
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
                .padding(.top, 16)
            }
        }
    }
}

struct UserSearchView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: SubscriptionViewModel
    @State private var searchText = ""
    @State private var searchDebouncer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            // Поле поиска
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Поиск пользователей...", text: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onChange(of: searchText) { _, newValue in
                        debouncedSearch(query: newValue)
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.thickMaterial)
            .cornerRadius(12)
            .padding(.top, 16)

            // Результаты поиска
            ScrollView {
                if viewModel.isSearching {
                    ProgressView("Поиск...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("Поиск пользователей")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        Text("Введите имя или username пользователя")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
                } else if viewModel.searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("Пользователи не найдены")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)

                        Text("Попробуйте изменить поисковый запрос")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults) { user in
                            SearchUserProfileRow(
                                user: user,
                                onFollowToggle: {
                                    // Обновляем список подписок после изменения
                                    Task {
                                        await viewModel.loadFollowing()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .onDisappear {
            searchText = ""
            viewModel.clearSearch()
        }
    }

    private func debouncedSearch(query: String) {
        // Отменяем предыдущий таймер
        searchDebouncer?.invalidate()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.clearSearch()
            return
        }

        // Создаем новый таймер с задержкой 500ms
        searchDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task {
                await viewModel.searchUsers(query: query)
            }
        }
    }
}

struct SearchUserProfileRow: View {
    @ObserveInjection var inject
    let user: UserProfile
    let onFollowToggle: () -> Void
    @State private var isFollowing = false
    @State private var isLoading = false

    var body: some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.id)) {
            HStack(spacing: 12) {
                // Аватар
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                // Информация о пользователе
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
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
                Button(action: {
                    Task {
                        await handleFollowToggle()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 60, height: 32)
                    } else {
                        Text(isFollowing ? "Отписаться" : "Подписаться")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isFollowing ? .red : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        isFollowing ? Color.red.opacity(0.1) : Color("AccentColor"))
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.thickMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            Task {
                await checkFollowingStatus()
            }
        }
    }

    private func checkFollowingStatus() async {
        let viewModel = SubscriptionViewModel()
        isFollowing = await viewModel.isFollowing(followingId: user.id)
    }

    private func handleFollowToggle() async {
        isLoading = true
        defer { isLoading = false }

        let viewModel = SubscriptionViewModel()

        if isFollowing {
            let success = await viewModel.unfollowUser(followingId: user.id)
            if success {
                isFollowing = false
            }
        } else {
            let success = await viewModel.followUser(followingId: user.id)
            if success {
                isFollowing = true
            }
        }

        onFollowToggle()
    }
}

struct UserProfileRow: View {
    @ObserveInjection var inject
    let user: UserProfile
    let isFollowing: Bool
    let onFollowToggle: () -> Void

    var body: some View {
        NavigationLink(destination: OtherUserProfileView(userId: user.id)) {
            HStack(spacing: 12) {
                // Аватар
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                // Информация о пользователе
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
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
                                .fill(isFollowing ? Color.red.opacity(0.1) : Color("AccentColor"))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.thickMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionManagementView()
}
