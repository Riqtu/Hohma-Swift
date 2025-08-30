//
//  WheelCardComponent.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI
import UniformTypeIdentifiers

struct WheelCardComponent: View {
    @ObserveInjection var inject
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var isImageLoaded: Bool = false

    let wheel: WheelWithRelations
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    init(
        wheel: WheelWithRelations,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.wheel = wheel
        self.onTap = onTap
        self.onDelete = onDelete
    }

    private var backgroundImage: some View {
        AsyncImage(url: URL(string: wheel.theme?.backgroundImageURL ?? "")) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .frame(width: 200, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(isImageLoaded ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5), value: isImageLoaded)
                    .onAppear {
                        isImageLoaded = true
                    }
            } else {
                // Placeholder пока загружается
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 160)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let avatarUrl = wheel.user?.avatarUrl {
                AsyncImage(url: avatarUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .opacity(isImageLoaded ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.3), value: isImageLoaded)
                            .onAppear {
                                isImageLoaded = true
                            }
                    } else {
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
        }
    }

    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color("AccentColor").opacity(0.8),
                            Color("AccentColor"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            Image(systemName: "circle.hexagonpath.fill")
                .font(.title2)
                .foregroundColor(.white)
        }
    }

    var body: some View {
        ZStack {
            backgroundImage
            VStack(alignment: .leading, spacing: 0) {
                // Основная карточка
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Верхняя часть с иконкой и статусом
                        HStack {
                            // Иконка колеса
                            ZStack {
                                avatarView
                            }

                            Spacer()

                            // Статус колеса
                            StatusBadge(status: wheel.status)
                        }

                        // Название колеса
                        Text(wheel.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Информация о дате создания
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(wheel.createdAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }

                        // Дополнительная информация
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(wheel.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                    .padding(16)
                    .frame(width: 200, height: 160)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.1), Color.primary.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isHovered ? .primary.opacity(0.15) : .black.opacity(0.05),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
                    .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHovered = hovering
                }
                .contextMenu {
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Удалить колесо", systemImage: "trash")
                        }
                    }

                    Button {
                        ShareService.shared.shareWheel(wheel: wheel)
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }

                }
            }
            .alert("Удалить колесо?", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    onDelete?()
                }
            } message: {
                Text("Это действие нельзя отменить. Колесо '\(wheel.name)' будет удалено навсегда.")
            }
            .enableInjection()
        }
    }
}

// Компонент для отображения статуса колеса
struct StatusBadge: View {
    let status: WheelStatus?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .inactive:
            return .orange
        case .created:
            return .blue
        case .completed:
            return .purple
        case nil:
            return .gray
        @unknown default:
            return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .active:
            return "Активно"
        case .inactive:
            return "Неактивно"
        case .created:
            return "Создано"
        case .completed:
            return "Завершено"
        case nil:
            return "Неизвестно"
        }
    }
}
