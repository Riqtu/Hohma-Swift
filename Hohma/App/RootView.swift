import Inject
import SwiftUI

struct RootView: View {
    @State private var selection: String = "home"
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @ObserveInjection var inject

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                // Показываем экран авторизации
                AuthView(viewModel: authViewModel)
            } else {
                if isSidebarPreferred {
                    NavigationSplitView {
                        CustomSidebar(selection: $selection, user: authViewModel.user)
                    } detail: {
                        Group {
                            switch selection {
                            case "wheelList":
                                WheelListView(user: authViewModel.user)
                                    .onAppear {
                                        // Сбрасываем состояние при переходе на экран колеса
                                        print("🔄 RootView: Navigating to wheel list")
                                    }
                            case "profile":
                                ProfileView(authViewModel: authViewModel)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to profile")
                                    }
                            case "settings":
                                SettingsView(viewModel: settingsViewModel)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to settings")
                                    }
                            default:
                                HomeView()
                                    .onAppear {
                                        print("🔄 RootView: Navigating to home")
                                    }
                            }
                        }
                    }

                } else {
                    TabView(selection: $selection) {

                        HomeView().withAppBackground()
                            .tabItem {
                                Label("Главная", systemImage: "house")
                            }
                            .tag("home")
                        WheelListView(user: authViewModel.user)
                            .withAppBackground()
                            .tabItem {
                                Label("Колесо", systemImage: "theatermasks.circle")
                            }
                            .tag("wheelList")

                        ProfileView(authViewModel: authViewModel)
                            .tabItem {
                                Label("Профиль", systemImage: "person")
                            }
                            .tag("profile")

                        SettingsView(viewModel: settingsViewModel)
                            .tabItem {
                                Label("Настройки", systemImage: "gearshape")
                            }
                            .tag("settings")
                    }
                    .tint(Color.primary)
                }
            }
        }
        .enableInjection()
        .onAppear {
            // Связываем AuthViewModel с NetworkManager для обработки 401 ошибок
            NetworkManager.shared.setAuthViewModel(authViewModel)

            // Подписываемся на уведомления об ошибках авторизации сокета
            NotificationCenter.default.addObserver(
                forName: .socketAuthorizationError,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    authViewModel.logout()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Обрабатываем уведомления о навигации
            if let destination = notification.userInfo?["destination"] as? String {
                let isForce = notification.userInfo?["force"] as? Bool ?? false
                print("🔄 RootView: Navigation requested to \(destination), force: \(isForce)")

                // Обновляем selection для навигации с приоритетом
                DispatchQueue.main.async {
                    self.selection = destination

                    // Если это принудительная навигация, добавляем дополнительную задержку
                    if isForce {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.selection = destination
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { _ in
            // Обрабатываем уведомления об обновлении данных колеса
            print("🔄 RootView: Wheel data updated")
        }
    }

    var isSidebarPreferred: Bool {
        #if os(macOS)
            return true
        #else
            return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
}

#Preview {
    RootView()
}
