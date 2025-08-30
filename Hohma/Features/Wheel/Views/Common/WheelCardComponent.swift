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
    @State private var showingEditForm: Bool = false

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

                            // Индикатор приватности
                            if wheel.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                            }

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

                        // Количество участников
                        HStack {
                            Image(systemName: "person.2")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(wheel.sectors.count) участников")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                    .padding(16)
                    .frame(width: 200, height: 160)
                    .background(.ultraThickMaterial.opacity(0.9))
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
                    // Кнопка редактирования (показываем только владельцу)
                    if wheel.userId == TRPCService.shared.currentUser?.id {
                        Button {
                            showingEditForm = true
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                    }

                    Button {
                        ShareService.shared.shareWheel(wheel: wheel)
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }

                    if wheel.userId == TRPCService.shared.currentUser?.id {

                        if onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Удалить колесо", systemImage: "trash")
                            }
                        }
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
            .sheet(isPresented: $showingEditForm) {
                EditWheelFormView(wheel: wheel)
                    .presentationDragIndicator(.visible)
            }
            .enableInjection()
        }
    }
}
