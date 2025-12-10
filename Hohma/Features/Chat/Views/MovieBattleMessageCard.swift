//
//  MovieBattleMessageCard.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import Inject
import SwiftUI

struct MovieBattleMessageCard: View {
    @ObserveInjection var inject
    let battle: MovieBattle
    let isCurrentUser: Bool
    @State private var battleToOpen: MovieBattle?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "film.fill")
                            .font(.caption)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary)
                        Text(battle.name)
                            .font(.headline)
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .lineLimit(2)
                        
                        if battle.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .secondary)
                        }
                    }
                    
                    // Информация о создателе
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption2)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .secondary)
                        Text(creatorName)
                            .font(.caption)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                MovieBattleStatusBadgeInMessage(status: battle.status, isCurrentUser: isCurrentUser)
            }
            
            Divider()
                .background(isCurrentUser ? Color.white.opacity(0.3) : Color.secondary.opacity(0.3))
                .padding(.vertical, 4)
            
            // Основная информация
            VStack(alignment: .leading, spacing: 8) {
                // Участники и фильмы
                HStack(spacing: 16) {
                    Label("\(battle.participantCount)", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                    
                    Label("\(battle.movieCount)/\(battle.maxMovies)", systemImage: "film.fill")
                        .font(.subheadline)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                    
                    Spacer()
                }
                
                // Прогресс сбора фильмов (если идет сбор)
                if battle.status == .collecting || battle.status == .created {
                    ProgressView(
                        value: Double(battle.movieCount), total: Double(battle.maxMovies)
                    )
                    .tint(isCurrentUser ? .white : .blue)
                    .frame(height: 4)
                }
                
                // Информация о раунде (если идет голосование)
                if battle.status == .voting {
                    HStack {
                        Label(
                            "Раунд \(battle.currentRound)",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.caption)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                        
                        if battle.moviesRemaining > 0 {
                            Text("•")
                                .foregroundColor(isCurrentUser ? .white.opacity(0.7) : .secondary)
                            Text("Осталось: \(battle.moviesRemaining)")
                                .font(.caption)
                                .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                        }
                    }
                }
            }
            
            // Кнопка перехода
            Button(action: {
                battleToOpen = battle
            }) {
                HStack {
                    Spacer()
                    Text("Открыть батл")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentUser ? .white : .primary)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    isCurrentUser 
                        ? Color.white.opacity(0.2) 
                        : Color(.systemGray5)
                )
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(
            isCurrentUser 
                ? Color("AccentColor") 
                : Color(.systemGray5)
        )
        .cornerRadius(16)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
        .fullScreenCover(isPresented: Binding(
            get: { battleToOpen != nil },
            set: { if !$0 { battleToOpen = nil } }
        )) {
            if let battle = battleToOpen {
                MovieBattleView(battleId: battle.id) {
                    battleToOpen = nil
                }
            }
        }
    }
    
    private var creatorName: String {
        battle.creator.name ?? battle.creator.username ?? "Неизвестный"
    }
}

// MARK: - MovieBattleStatusBadge для сообщений
struct MovieBattleStatusBadgeInMessage: View {
    @ObserveInjection var inject
    let status: MovieBattleStatus
    let isCurrentUser: Bool
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(6)
    }
    
    var statusColor: Color {
        let baseColor: Color
        switch status {
        case .created, .collecting:
            baseColor = .blue
        case .generating:
            baseColor = .orange
        case .voting:
            baseColor = .green
        case .finished:
            baseColor = .gray
        case .cancelled:
            baseColor = .red
        }
        
        if isCurrentUser {
            return baseColor.opacity(0.8)
        }
        return baseColor
    }
}

