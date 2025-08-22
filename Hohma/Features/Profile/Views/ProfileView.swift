import Inject
import SwiftUI

struct ProfileView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel: ProfileViewModel
    @State private var showEditProfile = false

    init(authViewModel: AuthViewModel) {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Заголовок
                headerSection

                // Информация о пользователе
                if let user = viewModel.user {
                    userInfoSection(user: user)
                }

                // Кнопка редактирования
                editButtonSection

                // Кнопки действий
                actionButtonsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .appBackground()
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.loadProfile()
        }
        .onAppear {
            viewModel.clearMessages()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfilePopup(viewModel: viewModel, isPresented: $showEditProfile)
                .presentationDragIndicator(.visible)
        }
        .enableInjection()
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
                            .foregroundColor(.white.opacity(0.8))
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
                infoRow(title: "Монеты", value: "\(user.coins)", icon: "dollarsign.circle.fill")
                infoRow(title: "Клики", value: "\(user.clicks)", icon: "hand.tap.fill")
                infoRow(
                    title: "Дата регистрации", value: formatDate(user.createdAt), icon: "calendar")
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
                .foregroundColor(.white.opacity(0.8))

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

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Кнопка выхода
            LogoutButton {
                viewModel.logout()
            }
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
