//
//  UserRowView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

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

            Spacer()
        }
        // .padding(10)

        .enableInjection()
    }

    private func getDisplayName() -> String {
        if let firstName = user.firstName, !firstName.isEmpty {
            return firstName
        } else if let username = user.username, !username.isEmpty {
            return username
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
        } else if let username = user.username, !username.isEmpty {
            return String(username.prefix(1)).uppercased()
        } else {
            return "?"
        }
    }
}

#Preview {
    UserRowView(
        user: AuthUser.mock,
        accentColor: "#F8D568"
    )
    .background(Color.black)
    .padding()
}
