import Inject
import SwiftUI

struct ProfileView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    @State private var showEditProfile = false

    init(authViewModel: AuthViewModel) {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Заголовок
                    headerSection

                    // Информация о пользователе
                    if let user = viewModel.user {
                        userInfoSection(user: user)
                    }
                    // Подписки
                    subscriptionsSection

                    // Кнопка редактирования
                    editButtonSection

                    Spacer()
                    // Кнопки действий
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .appBackground()

        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.loadProfile()
            await subscriptionViewModel.loadFollowing()
            await subscriptionViewModel.loadFollowers()
        }
        .onAppear {
            viewModel.clearMessages()
            Task {
                await subscriptionViewModel.loadFollowing()
                await subscriptionViewModel.loadFollowers()
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfilePopup(viewModel: viewModel, isPresented: $showEditProfile)
                .presentationDragIndicator(.visible)
        }
        .overlay(
            notificationOverlay
        )
        .enableInjection()
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
                AvatarView(
                    avatarUrl: user.avatarUrl,
                    size: 100,
                    fallbackColor: .accentColor,
                    showBorder: true,
                    borderColor: .accentColor
                )

                VStack(spacing: 4) {
                    Text(user.name ?? user.username ?? "Пользователь")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let email = user.email {
                        Text(email)
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
    private func userInfoSection(user: AuthUser) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Статистика")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(spacing: 12) {
                infoRow(
                    title: "Хохмокоины",
                    value: "\(user.coins)",
                    icon: "dollarsign.circle.fill"
                )
                infoRow(
                    title: "Клики",
                    value: "\(user.clicks)",
                    icon: "hand.tap.fill"
                )
                infoRow(
                    title: "Дата регистрации",
                    value: formatDate(user.createdAt),
                    icon: "calendar"
                )
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

    // MARK: - Edit Button Section
    private var editButtonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Управление профилем")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            PrimaryButton(title: "Редактировать профиль") {
                showEditProfile = true
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Subscriptions Section
    private var subscriptionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Подписки")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Статистика подписок
            HStack(spacing: 20) {
                subscriptionStatCard(
                    title: "Подписки",
                    count: subscriptionViewModel.following.count,
                    icon: "person.2.fill",
                    color: Color("AccentColor")
                )

                subscriptionStatCard(
                    title: "Подписчики",
                    count: subscriptionViewModel.followers.count,
                    icon: "person.3.fill",
                    color: Color("AccentColor")

                )
            }

            NavigationLink(destination: SubscriptionManagementView()) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)

                    Text("Управление подписками")
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private func subscriptionStatCard(title: String, count: Int, icon: String, color: Color)
        -> some View
    {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Кнопка выхода
            LogoutButton {
                viewModel.logout()
            }

            // Кнопка удаления аккаунта
            DeleteAccountButton(
                action: {
                    viewModel.deleteAccount()
                },
                isLoading: viewModel.isDeleting
            )
        }
    }

    // MARK: - Helper Methods
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }

        return dateString
    }
}

#Preview {
    NavigationView {
        ProfileView(authViewModel: AuthViewModel())
    }
}
