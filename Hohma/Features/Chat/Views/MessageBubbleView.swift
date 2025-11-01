//
//  MessageBubbleView.swift
//  Hohma
//
//  Created by Assistant on 30.10.2025.
//

import Inject
import SwiftUI

struct MessageBubbleView: View {
    @ObserveInjection var inject
    let message: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isCurrentUser {
                // Avatar for other users (слева)
                AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.sender?.displayName ?? "Пользователь")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color("AccentColor") : Color(.systemGray5))
                    .cornerRadius(16)

                HStack(spacing: 4) {
                    Text(formatDate(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isCurrentUser {
                        if message.status == .read {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if message.status == .delivered {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity * 0.75, alignment: isCurrentUser ? .trailing : .leading)

            if isCurrentUser {
                // Avatar for current user (справа)
                AsyncImage(url: URL(string: message.sender?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 4)
        .enableInjection()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                formatter.dateFormat = "HH:mm"
                return formatter.string(from: date)
            } else {
                formatter.dateFormat = "dd.MM HH:mm"
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

#Preview {
    let message1JSON = """
        {
            "id": "1",
            "chatId": "chat1",
            "senderId": "user1",
            "content": "Привет! Как дела?",
            "messageType": "TEXT",
            "attachments": [],
            "status": "SENT",
            "createdAt": "2025-10-30T12:00:00.000Z",
            "updatedAt": "2025-10-30T12:00:00.000Z"
        }
        """

    let message2JSON = """
        {
            "id": "2",
            "chatId": "chat1",
            "senderId": "user2",
            "content": "Все отлично, спасибо!",
            "messageType": "TEXT",
            "attachments": [],
            "status": "READ",
            "createdAt": "2025-10-30T12:01:00.000Z",
            "updatedAt": "2025-10-30T12:01:00.000Z"
        }
        """

    let decoder = JSONDecoder()
    let message1 = try? decoder.decode(ChatMessage.self, from: message1JSON.data(using: .utf8)!)
    let message2 = try? decoder.decode(ChatMessage.self, from: message2JSON.data(using: .utf8)!)

    return VStack {
        if let message1 = message1 {
            MessageBubbleView(message: message1, isCurrentUser: false)
        }

        if let message2 = message2 {
            MessageBubbleView(message: message2, isCurrentUser: true)
        }
    }
    .padding()
}
