import Inject
import SwiftUI

struct RootView: View {
    @State private var selection: String = "home"
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var chatListViewModel = ChatListViewModel()
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
                                ProfileView(authViewModel: authViewModel, useNavigationStack: false)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to profile")
                                    }
                            case "race":
                                RaceListView()
                                    .onAppear {
                                        print("🔄 RootView: Navigating to race")
                                    }
                            case "chat":
                                ChatListView(viewModel: chatListViewModel)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to chat")
                                    }
                            case "settings":
                                SettingsView(viewModel: settingsViewModel, authViewModel: authViewModel)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to settings")
                                    }
                            case "stats":
                                StatsView()
                                    .onAppear {
                                        print("🔄 RootView: Navigating to stats")
                                    }
                            case "movieBattle":
                                MovieBattleListView()
                                    .onAppear {
                                        print("🔄 RootView: Navigating to movie battle")
                                    }
                            default:
                                HomeView(user: authViewModel.user, authViewModel: authViewModel)
                                    .onAppear {
                                        print("🔄 RootView: Navigating to home")
                                    }
                            }
                        }
                    }

                } else {
                    TabView(selection: $selection) {

                        HomeView(user: authViewModel.user, authViewModel: authViewModel).withAppBackground()
                            .tabItem {
                                Label("Главная", systemImage: "house")
                            }
                            .tag("home")

                        NavigationStack {
                            MyMoviesListView()
                        }
                        .tabItem {
                            Label("Мои фильмы", systemImage: "film")
                        }
                        .tag("myMovies")

                        NavigationStack {
                            ChatListView(viewModel: chatListViewModel)
                                .withAppBackground()
                        }
                        .tabItem {
                            Label("Чаты", systemImage: "message")
                        }
                        .badge(chatListViewModel.totalUnreadCount)
                        .tag("chat")

                        SettingsView(viewModel: settingsViewModel, authViewModel: authViewModel)
                            .tabItem {
                                Label("Настройки", systemImage: "gearshape")
                            }
                            .tag("settings")
                    }
                }
            }
        }
        .enableInjection()
        .onAppear {
            print("🔗 RootView: ===== ROOT VIEW APPEARED =====")
            print("🔗 RootView: DeepLinkService shared instance: \(DeepLinkService.shared)")

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
            print("🔗 RootView: ===== ROOT VIEW SETUP COMPLETE =====")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Обрабатываем уведомления о навигации
            print("🔄 RootView: ===== NAVIGATION REQUESTED =====")
            print("🔄 RootView: Notification userInfo: \(notification.userInfo ?? [:])")

            if let destination = notification.userInfo?["destination"] as? String {
                let isForce = notification.userInfo?["force"] as? Bool ?? false
                print("🔄 RootView: Navigation requested to \(destination), force: \(isForce)")

                // Обновляем selection для навигации с приоритетом
                DispatchQueue.main.async {
                    // Маппим destination на правильные теги табов
                    let mappedDestination: String
                    switch destination {
                    case "wheel", "wheelList":
                        mappedDestination = "wheelList"
                    case "home":
                        mappedDestination = "home"
                    case "race":
                        mappedDestination = "race"
                    case "chat":
                        mappedDestination = "chat"
                    case "profile":
                        mappedDestination = "profile"
                    case "settings":
                        mappedDestination = "settings"
                    case "stats":
                        mappedDestination = "stats"
                    case "movieBattle":
                        mappedDestination = "movieBattle"
                    default:
                        mappedDestination = destination
                    }

                    print("🔄 RootView: Current selection: \(self.selection)")
                    print(
                        "🔄 RootView: Mapped destination '\(destination)' to '\(mappedDestination)'")

                    // Для iPhone (TabView): wheelList и race больше не существуют в табах,
                    // поэтому переключаемся на home, а навигация произойдёт через NavigationStack в HomeView
                    // Для iPad (NavigationSplitView): переключаем selection как обычно
                    if self.isSidebarPreferred {
                        // iPad: переключаем selection для NavigationSplitView
                        self.selection = mappedDestination
                        print("🔄 RootView: New selection set to: \(self.selection)")

                        // Если это принудительная навигация, добавляем дополнительную задержку
                        if isForce {
                            print("🔄 RootView: Force navigation - adding additional delay")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.selection = mappedDestination
                                print(
                                    "🔄 RootView: Force navigation - selection set again to: \(self.selection)"
                                )
                            }
                        }
                    } else {
                        // iPhone: переключаем selection только для существующих вкладок
                        // wheelList, race, stats и movieBattle обрабатываются через NavigationStack в HomeView
                        if mappedDestination == "wheelList" || mappedDestination == "race" || mappedDestination == "stats" || mappedDestination == "movieBattle" {
                            // Оставляем на home, HomeView сам обработает навигацию через NavigationPath
                            print(
                                "🔄 RootView: iPhone - навигация будет обработана в HomeView через NavigationStack"
                            )
                            // Убедимся, что мы на вкладке home
                            if self.selection != "home" {
                                self.selection = "home"
                                // Добавляем небольшую задержку перед отправкой уведомления в HomeView
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // HomeView уже обработает уведомление через onReceive
                                }
                            }
                        } else {
                            // Для остальных вкладок переключаем как обычно
                            self.selection = mappedDestination
                            print("🔄 RootView: New selection set to: \(self.selection)")

                            // Если это принудительная навигация, добавляем дополнительную задержку
                            if isForce {
                                print("🔄 RootView: Force navigation - adding additional delay")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    self.selection = mappedDestination
                                    print(
                                        "🔄 RootView: Force navigation - selection set again to: \(self.selection)"
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                print("🔄 RootView: ❌ No destination found in notification")
            }
            print("🔄 RootView: ===== NAVIGATION REQUEST COMPLETE =====")
        }
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { _ in
            // Обрабатываем уведомления об обновлении данных колеса
            print("🔄 RootView: Wheel data updated")
        }
        .onOpenURL { url in
            print("🔗 RootView: ===== ON OPEN URL RECEIVED =====")
            print("🔗 RootView: Received URL: \(url)")
            print("🔗 RootView: URL scheme: \(url.scheme ?? "nil")")
            print("🔗 RootView: URL host: \(url.host ?? "nil")")
            print("🔗 RootView: URL path: \(url.path)")
            print("🔗 RootView: URL pathComponents: \(url.pathComponents)")

            // Обрабатываем deep link через DeepLinkService
            if let wheelId = extractWheelIdFromURL(url) {
                print("🔗 RootView: ✅ Extracted wheel ID: \(wheelId)")
                DeepLinkService.shared.handleDeepLinkToWheel(wheelId: wheelId)
            } else {
                print("🔗 RootView: ❌ Failed to extract wheel ID from URL")
            }
            print("🔗 RootView: ===== ON OPEN URL COMPLETE =====")
        }
    }

    var isSidebarPreferred: Bool {
        #if os(macOS)
            return true
        #else
            return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    // MARK: - Deep Link Helper
    private func extractWheelIdFromURL(_ url: URL) -> String? {
        print("🔗 RootView: Extracting wheel ID from URL: \(url)")
        print("🔗 RootView: URL scheme: \(url.scheme ?? "nil")")
        print("🔗 RootView: URL host: \(url.host ?? "nil")")
        print("🔗 RootView: URL path: \(url.path)")
        print("🔗 RootView: URL pathComponents: \(url.pathComponents)")

        let pathComponents = url.pathComponents
        print("🔗 RootView: Path components: \(pathComponents)")

        // Для custom URL scheme: riqtu.Hohma://fortune-wheel/{wheelId}
        // host = "fortune-wheel", path = "/{wheelId}"
        if let host = url.host, host == "fortune-wheel" && pathComponents.count >= 2 {
            let wheelId = pathComponents[1]  // pathComponents[0] = "/", pathComponents[1] = wheelId
            print("🔗 RootView: Extracted wheel ID from custom scheme: \(wheelId)")
            return wheelId
        }

        // Дополнительная проверка для случая, когда wheelId находится в path без host
        // Например: riqtu.Hohma:///fortune-wheel/{wheelId} или riqtu.Hohma:///{wheelId}
        if pathComponents.count >= 2 {
            // Проверяем, есть ли "fortune-wheel" в path
            if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
                fortuneWheelIndex + 1 < pathComponents.count
            {
                let wheelId = pathComponents[fortuneWheelIndex + 1]
                print("🔗 RootView: Extracted wheel ID from path with fortune-wheel: \(wheelId)")
                return wheelId
            }

            // Если нет "fortune-wheel", но есть ID в path (например, riqtu.Hohma:///{wheelId})
            if pathComponents.count == 2 && pathComponents[0] == "/" {
                let wheelId = pathComponents[1]
                print("🔗 RootView: Extracted wheel ID from simple path: \(wheelId)")
                return wheelId
            }
        }

        // Для Universal Links: https://hohma.su/fortune-wheel/{wheelId}
        // Ищем индекс "fortune-wheel" в пути
        if let fortuneWheelIndex = pathComponents.firstIndex(of: "fortune-wheel"),
            fortuneWheelIndex + 1 < pathComponents.count
        {
            let wheelId = pathComponents[fortuneWheelIndex + 1]
            print("🔗 RootView: Extracted wheel ID from universal link: \(wheelId)")
            return wheelId
        }

        print("🔗 RootView: Failed to extract wheel ID")
        return nil
    }
}

#Preview {
    RootView()
}
