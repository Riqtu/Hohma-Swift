import Inject
import SwiftUI

struct RootView: View {
    @State private var selection: String = "home"
    @StateObject private var authViewModel = AuthViewModel()
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
                            case "profile":
                                ProfileView()
                            default:
                                HomeView()
                            }
                        }
                    }
                } else {
                    TabView(selection: $selection) {

                        HomeView().withAppBackground()

                            .tabItem {
                                Label("Главная", systemImage: "house")
                            }
                        WheelListView(user: authViewModel.user)
                            .withAppBackground()
                            .tabItem {
                                Label("Колесо", systemImage: "theatermasks.circle")
                            }
                            .tag("wheelList")

                        ProfileView()
                            .tabItem {
                                Label("Профиль", systemImage: "person")
                            }
                            .tag("profile")

                        MenuView()
                            .tabItem {
                                Label("Меню", systemImage: "filemenu.and.selection")
                            }
                            .tag("menu")
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
                authViewModel.logout()
            }
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
