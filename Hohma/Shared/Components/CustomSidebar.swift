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
                    Text("Разработчик")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    print("🔄 CustomSidebar: Switching to home")
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil, userInfo: ["destination": "home"])
                    selection = "home"
                }

                SidebarButton(
                    title: "Колесо",
                    icon: "theatermasks.circle",
                    isSelected: selection == "wheelList"
                ) {
                    print("🔄 CustomSidebar: Switching to wheel list")
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "wheelList"])
                    selection = "wheelList"
                }

                SidebarButton(
                    title: "Профиль",
                    icon: "person",
                    isSelected: selection == "profile"
                ) {
                    print("🔄 CustomSidebar: Switching to profile")
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "profile"])
                    selection = "profile"
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
                    print("🔄 CustomSidebar: Switching to settings")
                    // Отправляем уведомление о навигации
                    NotificationCenter.default.post(
                        name: .navigationRequested, object: nil,
                        userInfo: ["destination": "settings"])
                    selection = "settings"
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(minWidth: 180, alignment: .leading)
        .background(.ultraThinMaterial)
        .enableInjection()
    }
}
