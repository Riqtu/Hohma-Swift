//
//  WheelMessageCard.swift
//  Hohma
//
//  Created by Assistant
//

import Foundation
import Inject
import SwiftUI

struct WheelMessageCard: View {
    @ObserveInjection var inject
    let wheel: WheelWithRelations
    let isCurrentUser: Bool
    @State private var wheelToOpen: WheelWithRelations?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.dotted")
                            .font(.caption)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .primary)
                        Text(wheel.name)
                            .font(.headline)
                            .foregroundColor(isCurrentUser ? .white : .primary)
                            .lineLimit(2)
                        
                        if wheel.isPrivate {
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
            }
            
            Divider()
                .background(isCurrentUser ? Color.white.opacity(0.3) : Color.secondary.opacity(0.3))
                .padding(.vertical, 4)
            
            // Основная информация
            VStack(alignment: .leading, spacing: 8) {
                // Тема
                if let theme = wheel.theme {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette.fill")
                            .font(.caption)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                        Text(theme.title)
                            .font(.subheadline)
                            .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                            .lineLimit(1)
                    }
                }
                
                // Секторы
                if !wheel.sectors.isEmpty {
                    Label("\(wheel.sectors.count) секторов", systemImage: "circle.grid.3x3.fill")
                        .font(.subheadline)
                        .foregroundColor(isCurrentUser ? .white.opacity(0.9) : .secondary)
                }
            }
            
            // Кнопка перехода
            Button(action: {
                wheelToOpen = wheel
            }) {
                HStack {
                    Spacer()
                    Text("Открыть колесо")
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
        .fullScreenCover(item: $wheelToOpen) { wheel in
            NavigationView {
                FortuneWheelGameView(wheelData: wheel, currentUser: nil)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Назад") {
                                wheelToOpen = nil
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var creatorName: String {
        wheel.user?.name ?? wheel.user?.username ?? "Неизвестный"
    }
}

