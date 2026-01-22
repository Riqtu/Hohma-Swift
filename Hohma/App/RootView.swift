import Inject
import SwiftUI

struct RootView: View {
    @ObserveInjection var inject
    @State private var selection: String = "home"
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var chatListViewModel = ChatListViewModel()
    private let navigationCoordinator = NavigationCoordinator.shared

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
                                        AppLogger.shared.debug(
                                            "Navigating to wheel list", category: .ui)
                                    }
                            case "profile":
                                ProfileView(authViewModel: authViewModel, useNavigationStack: false)
                                    .onAppear {
                                        AppLogger.shared.debug(
                                            "Navigating to profile", category: .ui)
                                    }
                            case "race":
                                RaceListView()
                                    .onAppear {
                                        AppLogger.shared.debug("Navigating to race", category: .ui)
                                    }
                            case "chat":
                                ChatListView(viewModel: chatListViewModel)
                                    .onAppear {
                                        AppLogger.shared.debug("Navigating to chat", category: .ui)
                                    }
                            case "settings":
                                SettingsView(
                                    viewModel: settingsViewModel, authViewModel: authViewModel
                                )
                                .onAppear {
                                    AppLogger.shared.debug("Navigating to settings", category: .ui)
                                }
                            case "stats":
                                StatsView()
                                    .onAppear {
                                        AppLogger.shared.debug("Navigating to stats", category: .ui)
                                    }
                            case "movieBattle":
                                MovieBattleListView()
                                    .onAppear {
                                        AppLogger.shared.debug(
                                            "Navigating to movie battle", category: .ui)
                                    }
                            default:
                                HomeView(user: authViewModel.user, authViewModel: authViewModel)
                                    .onAppear {
                                        AppLogger.shared.debug("Navigating to home", category: .ui)
                                    }
                            }
                        }
                    }

                } else {
                    TabView(selection: $selection) {

                        HomeView(user: authViewModel.user, authViewModel: authViewModel)
                            .withAppBackground()
                            .tabItem {
                                Label("tab.home".localized, systemImage: "house")
                            }
                            .tag("home")

                        NavigationStack {
                            MyMoviesListView()
                        }
                        .tabItem {
                            Label("tab.myMovies".localized, systemImage: "film")
                        }
                        .tag("myMovies")

                        NavigationStack {
                            ChatListView(viewModel: chatListViewModel)
                                .withAppBackground()
                        }
                        .tabItem {
                            Label("tab.chat".localized, systemImage: "message")
                        }
                        .badge(chatListViewModel.totalUnreadCount)
                        .tag("chat")

                        SettingsView(viewModel: settingsViewModel, authViewModel: authViewModel)
                            .tabItem {
                                Label("tab.settings".localized, systemImage: "gearshape")
                            }
                            .tag("settings")
                    }
                }
            }
        }
        .enableInjection()
        .onAppear {
            AppLogger.shared.debug("===== ROOT VIEW APPEARED =====", category: .ui)
            AppLogger.shared.debug(
                "DeepLinkService shared instance: \(DeepLinkService.shared)", category: .ui)

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
            AppLogger.shared.debug("===== ROOT VIEW SETUP COMPLETE =====", category: .ui)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Обрабатываем уведомления о навигации
            AppLogger.shared.debug("===== NAVIGATION REQUESTED =====", category: .ui)
            AppLogger.shared.debug(
                "Notification userInfo: \(notification.userInfo ?? [:])", category: .ui)

            if let destination = notification.userInfo?["destination"] as? String {
                let isForce = notification.userInfo?["force"] as? Bool ?? false
                AppLogger.shared.debug(
                    "Navigation requested to \(destination), force: \(isForce)", category: .ui)

                // Маппим destination на правильные теги табов
                let mappedDestination = navigationCoordinator.mapDestination(destination)

                AppLogger.shared.debug("Current selection: \(self.selection)", category: .ui)
                AppLogger.shared.debug(
                    "RootView: Mapped destination '\(destination)' to '\(mappedDestination)'", category: .ui)
                
                Task { @MainActor in
                    await handleNavigation(
                        destination: destination,
                        mappedDestination: mappedDestination,
                        isForce: isForce
                    )
                }
            } else {
                AppLogger.shared.warning("No destination found in notification", category: .ui)
            }
            AppLogger.shared.debug("===== NAVIGATION REQUEST COMPLETE =====", category: .ui)
        }
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { _ in
            // Обрабатываем уведомления об обновлении данных колеса
            AppLogger.shared.debug("Wheel data updated", category: .ui)
        }
        .onOpenURL { url in
            AppLogger.shared.debug("===== ON OPEN URL RECEIVED =====", category: .ui)
            AppLogger.shared.debug("Received URL: \(url)", category: .ui)
            AppLogger.shared.debug("URL scheme: \(url.scheme ?? "nil")", category: .ui)
            AppLogger.shared.debug("URL host: \(url.host ?? "nil")", category: .ui)
            AppLogger.shared.debug("URL path: \(url.path)", category: .ui)
            AppLogger.shared.debug("URL pathComponents: \(url.pathComponents)", category: .ui)

            // Обрабатываем deep link через DeepLinkService
            if let wheelId = DeepLinkService.extractWheelId(from: url) {
                AppLogger.shared.debug("Extracted wheel ID: \(wheelId)", category: .ui)
                DeepLinkService.shared.handleDeepLinkToWheel(wheelId: wheelId)
            } else {
                AppLogger.shared.warning("Failed to extract wheel ID from URL", category: .ui)
            }
            AppLogger.shared.debug("===== ON OPEN URL COMPLETE =====", category: .ui)
        }
    }

    var isSidebarPreferred: Bool {
        #if os(macOS)
            return true
        #else
            return UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    
    // MARK: - Navigation Handling
    
    @MainActor
    private func handleNavigation(
        destination: String,
        mappedDestination: String,
        isForce: Bool
    ) async {
        // Для iPhone (TabView): wheelList и race больше не существуют в табах,
        // поэтому переключаемся на home, а навигация произойдёт через NavigationStack в HomeView
        // Для iPad (NavigationSplitView): переключаем selection как обычно
        if isSidebarPreferred {
            // iPad: переключаем selection для NavigationSplitView
            selection = mappedDestination
            AppLogger.shared.debug(
                "New selection set to: \(selection)", category: .ui)

            // Если это принудительная навигация, добавляем дополнительную задержку
            if isForce {
                AppLogger.shared.debug(
                    "Force navigation - adding additional delay", category: .ui)
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
                selection = mappedDestination
                AppLogger.shared.debug(
                    "RootView: Force navigation - selection set again to: \(selection)", category: .ui)
            }
        } else {
            // iPhone: переключаем selection только для существующих вкладок
            // wheelList, race, stats и movieBattle обрабатываются через NavigationStack в HomeView
            if navigationCoordinator.shouldHandleViaHomeView(destination, isSidebarPreferred: isSidebarPreferred) {
                // Оставляем на home, HomeView сам обработает навигацию через NavigationPath
                AppLogger.shared.debug(
                    "RootView: iPhone - навигация будет обработана в HomeView через NavigationStack", category: .ui)
                // Убедимся, что мы на вкладке home
                if selection != "home" {
                    selection = "home"
                    // HomeView уже обработает уведомление через onReceive
                }
            } else {
                // Для остальных вкладок переключаем как обычно
                selection = mappedDestination
                AppLogger.shared.debug(
                    "New selection set to: \(selection)", category: .ui)

                // Если это принудительная навигация, добавляем дополнительную задержку
                if isForce {
                    AppLogger.shared.debug(
                        "Force navigation - adding additional delay", category: .ui)
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
                    selection = mappedDestination
                    AppLogger.shared.debug(
                        "RootView: Force navigation - selection set again to: \(selection)", category: .ui)
                }
            }
        }
    }
}

#Preview {
    RootView()
}
