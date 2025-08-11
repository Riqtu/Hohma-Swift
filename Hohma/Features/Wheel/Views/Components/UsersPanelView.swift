//
//  UsersPanelView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

struct UsersPanelView: View {
    @ObserveInjection var inject
    let users: [AuthUser]
    let accentColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Участники (\(users.count))")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: accentColor))

            if users.isEmpty {
                Text("Нет участников")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(users.prefix(5)) { user in
                        UserRowView(user: user, accentColor: accentColor)
                    }

                    if users.count > 5 {
                        Text("+\(users.count - 5) еще")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 200)
    }
}

struct UserRowView: View {
    @ObserveInjection var inject
    let user: AuthUser
    let accentColor: String

    var body: some View {
        HStack(spacing: 8) {
            // Аватар пользователя
            if let avatarUrl = user.avatarUrl {
                AsyncImage(url: avatarUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: accentColor), lineWidth: 2))
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }

            // Информация о пользователе
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(user.coins) монет")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    UsersPanelView(
        users: [
            AuthUser.mock,
            AuthUser.mock,
        ],
        accentColor: "#F8D568"
    )
    .background(Color.black)
}
