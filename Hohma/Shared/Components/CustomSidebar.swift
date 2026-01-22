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
                    Text(user?.user.firstName ?? "common.anonymous".localized)
                        .font(.headline)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)

            Divider()

            // Меню
            VStack(alignment: .leading, spacing: 6) {
                SidebarButton(
                    title: "sidebar.home".localized,
                    icon: "house",
                    isSelected: selection == "home"
                ) {
                    AppLogger.shared.debug("Switching to home", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil, userInfo: ["destination": "home"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "home"
                    }
                }

                SidebarButton(
                    title: "sidebar.wheel".localized,
                    icon: "theatermasks.circle",
                    isSelected: selection == "wheelList"
                ) {
                    AppLogger.shared.debug("Switching to wheel list", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "wheelList"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "wheelList"
                    }
                }

                SidebarButton(
                    title: "sidebar.race".localized,
                    icon: "trophy",
                    isSelected: selection == "race"
                ) {
                    AppLogger.shared.debug("Switching to race", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "race"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "race"
                    }
                }

                SidebarButton(
                    title: "sidebar.movieBattle".localized,
                    icon: "film",
                    isSelected: selection == "movieBattle"
                ) {
                    AppLogger.shared.debug("Switching to movie battle", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "movieBattle"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "movieBattle"
                    }
                }

                SidebarButton(
                    title: "sidebar.stats".localized,
                    icon: "chart.bar.fill",
                    isSelected: selection == "stats"
                ) {
                    AppLogger.shared.debug("Switching to stats", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "stats"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "stats"
                    }
                }

                SidebarButton(
                    title: "sidebar.chat".localized,
                    icon: "message",
                    isSelected: selection == "chat"
                ) {
                    AppLogger.shared.debug("Switching to chat", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "chat"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
                        selection = "chat"
                    }
                }

                SidebarButton(
                    title: "sidebar.profile".localized,
                    icon: "person",
                    isSelected: selection == "profile"
                ) {
                    AppLogger.shared.debug("Switching to profile", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "profile"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
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
                    title: "sidebar.settings".localized,
                    icon: "gearshape",
                    isSelected: selection == "settings"
                ) {
                    AppLogger.shared.debug("Switching to settings", category: .ui)
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "settings"])
                    // Обновляем selection с небольшой задержкой для надежности
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 секунды
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
