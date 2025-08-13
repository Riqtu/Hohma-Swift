//
//  UsersPanelView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct UsersPanelView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: FortuneWheelViewModel
    let accentColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Участники (\(viewModel.roomUsers.count))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: accentColor))

                Spacer()

                // Индикатор подключения сокета
                Circle()
                    .fill(viewModel.isSocketReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .onAppear {
                print("👥 UsersPanelView: Appeared with \(viewModel.roomUsers.count) users")
            }
            .onChange(of: viewModel.roomUsers.count) { newCount in
                print("👥 UsersPanelView: Users count changed to \(newCount)")
            }

            if viewModel.roomUsers.isEmpty {
                VStack(spacing: 8) {
                    Text("Нет участников")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !viewModel.isSocketReady {
                        Text("Подключение...")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.roomUsers.prefix(8)) { user in
                        UserRowView(user: user, accentColor: accentColor)
                    }

                    if viewModel.roomUsers.count > 8 {
                        Text("+\(viewModel.roomUsers.count - 8) еще")
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
        .frame(maxWidth: 220)
        .animation(.easeInOut(duration: 0.3), value: viewModel.roomUsers.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSocketReady)
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
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: accentColor), lineWidth: 2))
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(getUserInitials())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(getUserInitials())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }

            // Информация о пользователе
            VStack(alignment: .leading, spacing: 2) {
                Text(getDisplayName())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(user.coins)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: accentColor))

                    Text("монет")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: accentColor).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func getDisplayName() -> String {
        if let firstName = user.firstName, !firstName.isEmpty {
            return firstName
        } else if !user.username.isEmpty {
            return user.username
        } else {
            return "Пользователь"
        }
    }

    private func getUserInitials() -> String {
        let firstName = user.firstName?.isEmpty == false ? String(user.firstName!.prefix(1)) : ""
        let lastName = user.lastName?.isEmpty == false ? String(user.lastName!.prefix(1)) : ""

        if !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName)\(lastName)".uppercased()
        } else if !firstName.isEmpty {
            return firstName.uppercased()
        } else if !user.username.isEmpty {
            return String(user.username.prefix(1)).uppercased()
        } else {
            return "?"
        }
    }
}

// #Preview {
//     UsersPanelView(
//         viewModel: FortuneWheelViewModel(...),
//         accentColor: "#F8D568"
//     )
//     .background(Color.black)
// }
