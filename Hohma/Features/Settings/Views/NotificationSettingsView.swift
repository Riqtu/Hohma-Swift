//
//  NotificationSettingsView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct NotificationSettingsView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Фон
                AppBackground(useVideoBackground: false)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Основные настройки
                        mainSettingsSection

                        // Детальные настройки
                        detailedSettingsSection

                        // Тестовые уведомления
                        testSection

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        viewModel.saveSettings()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay(
                notificationOverlay
            )
        }
        .enableInjection()
    }

    // MARK: - Main Settings Section
    private var mainSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Основные настройки")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                // Статус push-уведомлений
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Push-уведомления")
                            .font(.body)
                            .foregroundColor(.primary)

                        Text(viewModel.isPushEnabled ? "Включены" : "Отключены")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if viewModel.isPushEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button("Включить") {
                            viewModel.requestPushAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )

                // Кнопка настроек системы
                if !viewModel.isPushEnabled {
                    Button("Открыть настройки") {
                        viewModel.openSettings()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Detailed Settings Section
    private var detailedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Типы уведомлений")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "Новые подписчики",
                    subtitle: "Уведомления о новых подписчиках",
                    isEnabled: $viewModel.isNewFollowerEnabled,
                    icon: "person.badge.plus"
                )

                NotificationToggleRow(
                    title: "Новые лайки",
                    subtitle: "Уведомления о лайках ваших постов",
                    isEnabled: $viewModel.isNewLikeEnabled,
                    icon: "heart"
                )

                NotificationToggleRow(
                    title: "Новые комментарии",
                    subtitle: "Уведомления о комментариях",
                    isEnabled: $viewModel.isNewCommentEnabled,
                    icon: "message"
                )

                NotificationToggleRow(
                    title: "Приглашения в колесо",
                    subtitle: "Уведомления о приглашениях",
                    isEnabled: $viewModel.isWheelInvitationEnabled,
                    icon: "gamecontroller"
                )

                NotificationToggleRow(
                    title: "Результаты колеса",
                    subtitle: "Уведомления о результатах",
                    isEnabled: $viewModel.isWheelResultEnabled,
                    icon: "trophy"
                )

                NotificationToggleRow(
                    title: "Общие уведомления",
                    subtitle: "Другие важные уведомления",
                    isEnabled: $viewModel.isGeneralEnabled,
                    icon: "bell"
                )
            }
        }
    }

    // MARK: - Test Section
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Тестирование")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                Button("Отправить тестовое уведомление") {
                    viewModel.sendTestNotification()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!viewModel.isPushEnabled || viewModel.isLoading)

                Text("Отправьте тестовое уведомление, чтобы проверить настройки")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
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
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    NotificationSettingsView()
}

