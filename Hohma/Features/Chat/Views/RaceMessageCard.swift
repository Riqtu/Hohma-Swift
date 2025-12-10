//
//  RaceMessageCard.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import Inject
import SwiftUI

struct RaceMessageCard: View {
    @ObserveInjection var inject
    let race: Race
    let isCurrentUser: Bool
    @State private var raceToOpen: Race?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.caption)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary)
                        Text(race.name)
                            .font(.headline)
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .lineLimit(2)
                        
                        if race.isPrivate {
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
                
                RaceStatusBadgeInMessage(status: race.status, isCurrentUser: isCurrentUser)
            }
            
            Divider()
                .background(isCurrentUser ? Color.white.opacity(0.3) : Color.secondary.opacity(0.3))
                .padding(.vertical, 4)
            
            // Основная информация
            VStack(alignment: .leading, spacing: 8) {
                // Дорога
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .font(.caption)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                    Text(race.road.name)
                        .font(.subheadline)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                }
                
                // Участники
                HStack(spacing: 16) {
                    Label(
                        "\(race.participantCount ?? race.participants?.count ?? 0)/\(race.maxPlayers)",
                        systemImage: "person.3.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                    
                    if race.entryFee > 0 {
                        Label("\(race.entryFee) монет", systemImage: "dollarsign.circle")
                            .font(.subheadline)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                    }
                    
                    if race.prizePool > 0 {
                        Label("\(race.prizePool) монет", systemImage: "trophy.fill")
                            .font(.subheadline)
                            .foregroundColor(isCurrentUser ? .orange.opacity(0.9) : .orange)
                    }
                    
                    Spacer()
                }
            }
            
            // Кнопка перехода
            Button(action: {
                raceToOpen = race
            }) {
                HStack {
                    Spacer()
                    Text("Открыть скачку")
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
        .fullScreenCover(item: $raceToOpen) { race in
            NavigationView {
                RaceSceneView(race: race)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Назад") {
                                raceToOpen = nil
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var creatorName: String {
        race.creator.name ?? race.creator.username ?? "Неизвестный"
    }
}

// MARK: - RaceStatusBadge для сообщений
struct RaceStatusBadgeInMessage: View {
    @ObserveInjection var inject
    let status: RaceStatus
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
        case .created:
            baseColor = .blue
        case .waiting:
            baseColor = .yellow
        case .running:
            baseColor = .green
        case .finished:
            baseColor = .purple
        case .cancelled:
            baseColor = .red
        }
        
        if isCurrentUser {
            return baseColor.opacity(0.8)
        }
        return baseColor
    }
}

