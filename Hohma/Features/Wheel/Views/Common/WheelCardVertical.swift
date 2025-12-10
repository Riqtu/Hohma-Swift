//
//  WheelCardVertical.swift
//  Hohma
//
//  Created by Assistant
//

import Inject
import SwiftUI

struct WheelCardVertical: View {
    @ObserveInjection var inject
    let wheel: WheelWithRelations
    let onTap: () -> Void
    let onDelete: ((String) -> Void)?
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wheel.name)
                        .font(.headline)
                    if let theme = wheel.theme {
                        Text(theme.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                if wheel.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                if let user = wheel.user {
                    CachedAsyncImage(url: user.avatarUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(user.name ?? user.username ?? "Неизвестно")
                            .font(.caption)
                        Text(wheel.createdAt.formattedString())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundColor(Color("AccentColor"))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                NotificationCenter.default.post(
                    name: .shareWheel,
                    object: nil,
                    userInfo: ["wheel": wheel]
                )
            } label: {
                Label("Поделиться в чате", systemImage: "arrow.up.right.square")
            }

            if onDelete != nil {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
        .alert("Удалить колесо?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                onDelete?(wheel.id)
            }
        } message: {
            Text("Это действие нельзя отменить")
        }
    }
}
