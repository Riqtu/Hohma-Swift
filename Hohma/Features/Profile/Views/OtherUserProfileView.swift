//
//  OtherUserProfileView.swift
//  Hohma
//
//  Created by Assistant on 20.08.2025.
//

import Inject
import SwiftUI

struct OtherUserProfileView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel: OtherUserProfileViewModel
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let useNavigationStack: Bool

    init(userId: String, useNavigationStack: Bool = true) {
        self.userId = userId
        self.useNavigationStack = useNavigationStack
        self._viewModel = StateObject(wrappedValue: OtherUserProfileViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if useNavigationStack {
                NavigationStack {
                    profileContent
                }
            } else {
                profileContent
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadUserProfile()
            await subscriptionViewModel.checkFollowingStatus(userId: userId)
        }
        .overlay(
            notificationOverlay
        )
        .enableInjection()
    }
    
    private var profileContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Заголовок с аватаром и информацией
                headerSection

                // Статистика пользователя
                if let user = viewModel.user {
                    userInfoSection(user: user)
                }

                // Кнопка подписки/отписки
                subscriptionButtonSection

                // Список колес пользователя (если есть)
                if !viewModel.userWheels.isEmpty {
                    userWheelsSection
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .appBackground()
        .onAppear {
            Task {
                await viewModel.loadUserProfile()
                await subscriptionViewModel.checkFollowingStatus(userId: userId)
            }
        }
    }

    // MARK: - Notification Overlay
    private var notificationOverlay: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                notificationView(message: errorMessage, type: .error)
            }

            if let successMessage = viewModel.successMessage {
                notificationView(message: successMessage, type: .success)
            }
        }
    }

    private func notificationView(message: String, type: NotificationView.NotificationType)
        -> some View
    {
        VStack {
            NotificationView(
                message: message,
                type: type
            ) {
                viewModel.clearMessages()
            }
            Spacer()
        }
        .padding(.top, 60)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            if let user = viewModel.user {
                CachedAsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.accentColor)
                        .frame(width: 100, height: 100)
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                )

                VStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let username = user.username {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - User Info Section
    private func userInfoSection(user: UserProfile) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Информация")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(spacing: 12) {
                if let name = user.name, !name.isEmpty {
                    infoRow(
                        title: "Имя",
                        value: name,
                        icon: "person.fill"
                    )
                }

                if let firstName = user.firstName, !firstName.isEmpty {
                    infoRow(
                        title: "Имя",
                        value: firstName,
                        icon: "person.fill"
                    )
                }

                if let lastName = user.lastName, !lastName.isEmpty {
                    infoRow(
                        title: "Фамилия",
                        value: lastName,
                        icon: "person.fill"
                    )
                }

                if let username = user.username, !username.isEmpty {
                    infoRow(
                        title: "Username",
                        value: "@\(username)",
                        icon: "at"
                    )
                }

                if let email = user.email, !email.isEmpty {
                    infoRow(
                        title: "Email",
                        value: email,
                        icon: "envelope"
                    )
                }

                if let coins = user.coins {
                    infoRow(
                        title: "Хохмокоины",
                        value: "\(coins)",
                        icon: "dollarsign.circle.fill"
                    )
                }

                if let clicks = user.clicks {
                    infoRow(
                        title: "Клики",
                        value: "\(clicks)",
                        icon: "hand.tap.fill"
                    )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(title)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Subscription Button Section
    private var subscriptionButtonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Действия")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Button(action: {
                Task {
                    await handleSubscriptionToggle()
                }
            }) {
                HStack {
                    Image(
                        systemName: subscriptionViewModel.isFollowing
                            ? "person.badge.minus" : "person.badge.plus"
                    )
                    .foregroundColor(.white)

                    Text(subscriptionViewModel.isFollowing ? "Отписаться" : "Подписаться")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(subscriptionViewModel.isFollowing ? Color.red : Color("AccentColor"))
                )
            }
            .disabled(subscriptionViewModel.isLoading)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - User Wheels Section
    private var userWheelsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Колеса пользователя")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            LazyVStack(spacing: 12) {
                ForEach(viewModel.userWheels, id: \.id) { wheel in
                    WheelCardRow(wheel: wheel)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Helper Methods
    private func handleSubscriptionToggle() async {
        if subscriptionViewModel.isFollowing {
            let success = await subscriptionViewModel.unfollowUser(followingId: userId)
            if success {
                viewModel.successMessage = "Вы отписались от пользователя"
            } else {
                viewModel.errorMessage = "Ошибка при отписке"
            }
        } else {
            let success = await subscriptionViewModel.followUser(followingId: userId)
            if success {
                viewModel.successMessage = "Вы подписались на пользователя"
            } else {
                viewModel.errorMessage = "Ошибка при подписке"
            }
        }
    }
}

// MARK: - Wheel Card Row
struct WheelCardRow: View {
    @ObserveInjection var inject
    let wheel: Wheel

    var body: some View {
        HStack(spacing: 12) {
            // Иконка колеса
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color("AccentColor").opacity(0.8), Color("AccentColor")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "circle.hexagonpath.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            // Информация о колесе
            VStack(alignment: .leading, spacing: 4) {
                Text(wheel.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Создано \(formatDate(wheel.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Статус колеса
            StatusBadge(status: wheel.status)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .enableInjection()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    OtherUserProfileView(userId: "test-user-id")
}
