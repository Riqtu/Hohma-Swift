import Inject
//
//  CustomSidebar.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//
import SwiftUI

struct CustomSidebar: View {
    @ObserveInjection var inject
    @Binding var selection: String
    let user: AuthResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Аватарка и имя
            HStack {
                if let url = user?.user.avatarUrl {
                    AsyncImage(url: url) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.accentColor)
                }
                VStack(alignment: .leading) {
                    Text(user?.user.firstName ?? "Аноним")
                        .font(.headline)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)

            Divider()

            // Меню
            VStack(alignment: .leading, spacing: 6) {
                SidebarButton(
                    title: "Главная",
                    icon: "house",
                    isSelected: selection == "home"
                ) {
                    AppLogger.shared.debug("Switching to home", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil, userInfo: ["destination": "home"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "home"
                    }
                }

                SidebarButton(
                    title: "Колесо",
                    icon: "theatermasks.circle",
                    isSelected: selection == "wheelList"
                ) {
                    AppLogger.shared.debug("Switching to wheel list", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "wheelList"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "wheelList"
                    }
                }

                SidebarButton(
                    title: "Скачки",
                    icon: "trophy",
                    isSelected: selection == "race"
                ) {
                    AppLogger.shared.debug("Switching to race", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "race"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "race"
                    }
                }

                SidebarButton(
                    title: "Битва фильмов",
                    icon: "film",
                    isSelected: selection == "movieBattle"
                ) {
                    AppLogger.shared.debug("Switching to movie battle", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "movieBattle"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "movieBattle"
                    }
                }

                SidebarButton(
                    title: "Статистика",
                    icon: "chart.bar.fill",
                    isSelected: selection == "stats"
                ) {
                    AppLogger.shared.debug("Switching to stats", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "stats"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "stats"
                    }
                }

                SidebarButton(
                    title: "Чаты",
                    icon: "message",
                    isSelected: selection == "chat"
                ) {
                    AppLogger.shared.debug("Switching to chat", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "chat"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "chat"
                    }
                }

                SidebarButton(
                    title: "Профиль",
                    icon: "person",
                    isSelected: selection == "profile"
                ) {
                    AppLogger.shared.debug("Switching to profile", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "profile"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "profile"
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 8)

            Spacer()

            Divider()

            // Нижний блок, например, настройки
            VStack(alignment: .leading) {
                SidebarButton(
                    title: "Настройки",
                    icon: "gearshape",
                    isSelected: selection == "settings"
                ) {
                    AppLogger.shared.debug("Switching to settings", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "settings"])
                    // Обновляем selection с небольшой задержкой для надежности
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selection = "settings"
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(minWidth: 180, alignment: .leading)
        .background(.ultraThinMaterial)
        .enableInjection()
    }
}
