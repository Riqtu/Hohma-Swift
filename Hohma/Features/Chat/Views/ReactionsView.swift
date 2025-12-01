//
//  ReactionsView.swift
//  Hohma
//
//  Created by Assistant on 30.11.2025.
//

import SwiftUI
import Inject

struct ReactionsView: View {
    @ObserveInjection var inject
    let reactions: [MessageReaction]
    let currentUserId: String?
    let onReactionTap: (String) -> Void
    
    // Группируем реакции по эмодзи
    private var groupedReactions: [String: [MessageReaction]] {
        Dictionary(grouping: reactions) { $0.emoji }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(groupedReactions.keys.sorted()), id: \.self) { emoji in
                if let emojiReactions = groupedReactions[emoji] {
                    ReactionButton(
                        emoji: emoji,
                        reactions: emojiReactions,
                        isSelected: emojiReactions.contains { $0.userId == currentUserId },
                        onTap: {
                            onReactionTap(emoji)
                        }
                    )
                }
            }
        }
    }
}

struct ReactionButton: View {
    @ObserveInjection var inject
    let emoji: String
    let reactions: [MessageReaction]
    let isSelected: Bool
    let onTap: () -> Void
    
    // Показываем до 3 аватаров, остальные скрываем
    private var avatarsToShow: [MessageReaction] {
        Array(reactions.prefix(3))
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // Аватары пользователей
                HStack(spacing: -6) {
                    ForEach(avatarsToShow) { reaction in
                        AsyncImage(url: URL(string: reaction.user?.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 1)
                        )
                    }
                }
                
                // Эмодзи
                Text(emoji)
                    .font(.system(size: 16))
                
                // Счетчик, если реакций больше 3
                if reactions.count > 3 {
                    Text("\(reactions.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReactionPickerView: View {
    @ObserveInjection var inject
    let message: ChatMessage
    let onReactionSelected: (String) -> Void
    
    private let commonEmojis = ["👍", "❤️", "😂", "😮", "😢", "🙏", "🔥", "👏"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Выберите реакцию")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                ForEach(commonEmojis, id: \.self) { emoji in
                    Button(action: {
                        onReactionSelected(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 40))
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.height(300)])
    }
}

