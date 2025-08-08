import SwiftUI
import Inject
struct RootView: View {
    @State private var selection: String = "home"
    @StateObject private var authViewModel = AuthViewModel()
        @ObserveInjection var inject

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
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
                        ZStack {
                            AnimatedGradientBackground()
                            HomeView()
                        }
                        .tabItem {
                            Label("Главная", systemImage: "house")
                        }
                        .tag("home")
                        ZStack {
                            AnimatedGradientBackground()
                            WheelListView(user: authViewModel.user)     }                       .tabItem {
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
                    //                    .background(Color.clear)
                    
                }
            }
        }
        .enableInjection()
        
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
