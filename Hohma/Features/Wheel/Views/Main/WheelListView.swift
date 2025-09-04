//
//  WheelCard.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

// Структура для частичных закруглений
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct WheelListView: View {
    let user: AuthResult?
    @ObserveInjection var inject
    @StateObject private var viewModel: WheelListViewModel
    @State private var showingCreateForm = false
    @StateObject private var deepLinkService = DeepLinkService.shared

    @State private var showingGame = false
    @State private var selectedWheel: WheelWithRelations?
    @Environment(\.scenePhase) private var scenePhase

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Кастомный заголовок с закруглениями внизу
            HStack {
                Text("Колесо фортуны")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showingCreateForm = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("AccentColor"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(.thickMaterial)
            .clipShape(
                RoundedCorner(
                    radius: 16,
                    corners: .bottomLeft.union(.bottomRight)
                )
            )
            .overlay(alignment: .top) {
                Color.clear  // Or any view or color
                    .background(.thickMaterial)  // I put clear here because I prefer to put a blur in this case. This modifier and the material it contains are optional.
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 0)  // This will constrain the overlay to only go above the top safe area and not under.
            }
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)

            ScrollView {
                VStack(spacing: 10) {
                    // Секция "Все колеса"
                    HorizontalWheelSectionView(
                        title: "Все колеса",
                        wheels: viewModel.allWheels,
                        isLoading: viewModel.isLoading,
                        isLoadingMore: viewModel.allWheelsLoadingMore,
                        hasMoreData: viewModel.allWheelsHasMore,
                        onWheelTap: { wheel in
                            print("🎯 WheelListView: Нажато колесо: \(wheel.name) с ID: \(wheel.id)")
                            selectedWheel = wheel
                            showingGame = true
                        },
                        onWheelDelete: { wheelId in
                            Task {
                                await viewModel.deleteWheel(withId: wheelId)
                            }
                        },
                        onLoadMore: {
                            await viewModel.loadMoreAllWheels()
                        }
                    )
                    // Секция "Мои колеса"
                    HorizontalWheelSectionView(
                        title: "Мои колеса",
                        wheels: viewModel.myWheels,
                        isLoading: viewModel.isLoading,
                        isLoadingMore: viewModel.myWheelsLoadingMore,
                        hasMoreData: viewModel.myWheelsHasMore,
                        onWheelTap: { wheel in
                            print("🎯 WheelListView: Нажато колесо: \(wheel.name) с ID: \(wheel.id)")
                            selectedWheel = wheel
                            showingGame = true
                        },
                        onWheelDelete: { wheelId in
                            Task {
                                await viewModel.deleteWheel(withId: wheelId)
                            }
                        },
                        onLoadMore: {
                            await viewModel.loadMoreMyWheels()
                        }
                    )

                    // Секция "Колеса подписок"
                    HorizontalWheelSectionView(
                        title: "Подписки",
                        wheels: viewModel.followingWheels,
                        isLoading: viewModel.isLoading,
                        isLoadingMore: viewModel.followingWheelsLoadingMore,
                        hasMoreData: viewModel.followingWheelsHasMore,
                        onWheelTap: { wheel in
                            print("🎯 WheelListView: Нажато колесо: \(wheel.name) с ID: \(wheel.id)")
                            selectedWheel = wheel
                            showingGame = true
                        },
                        onWheelDelete: { wheelId in
                            Task {
                                await viewModel.deleteWheel(withId: wheelId)
                            }
                        },
                        onLoadMore: {
                            await viewModel.loadMoreFollowingWheels()
                        }
                    )
                }
            }
            .padding(.top, 20)
            .onAppear {
                print("🔗 WheelListView: ===== VIEW APPEARED =====")
                Task {
                    await viewModel.loadWheelsSmartWithAutoLoad()
                }

                // Проверяем, есть ли pending deep link
                print("🔗 WheelListView: Checking for pending deep link...")
                checkAndHandleDeepLink()
                print("🔗 WheelListView: ===== VIEW APPEAR COMPLETE =====")
            }
            .onDisappear {
                // Сохраняем состояние пагинации при уходе с экрана
                viewModel.savePaginationStateNow()
            }
            .refreshable {
                Task {
                    await viewModel.refreshWheels()
                }
            }
            .onReceive(deepLinkService.$pendingWheelId) { wheelId in
                // Обрабатываем deep link когда он становится доступным
                if let wheelId = wheelId {
                    handleDeepLinkWheel(wheelId: wheelId)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .appBackground()
        .modifier(
            NavigationModifier(
                showingGame: $showingGame,
                selectedWheel: selectedWheel,
                user: user,
                isSidebarPreferred: UIDevice.current.userInterfaceIdiom == .pad
            )
        )
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { notification in
            print("🔄 WheelListView: Received wheel data update notification")
            // ИСПРАВЛЕНИЕ: Умное обновление данных без потери позиции в списке
            // Получаем ID обновленного колеса из уведомления, если оно есть
            if let wheelId = notification.userInfo?["wheelId"] as? String {
                // Обновляем только конкретное колесо
                Task {
                    await viewModel.updateSpecificWheel(wheelId: wheelId)
                }
            } else {
                // Если ID нет, обновляем только видимые колеса без полной перезагрузки
                Task {
                    await viewModel.loadWheelsSmartWithAutoLoad()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigationRequested)) {
            notification in
            // Обрабатываем уведомления о навигации к колесу
            print("🔗 WheelListView: Received navigationRequested notification")
            print("🔗 WheelListView: Notification userInfo: \(notification.userInfo ?? [:])")
            print(
                "🔗 WheelListView: Current view state - showingGame: \(showingGame), selectedWheel: \(selectedWheel?.id ?? "nil")"
            )

            if let destination = notification.userInfo?["destination"] as? String {
                print("🔗 WheelListView: Destination: \(destination)")
                if destination == "wheel",
                    let wheelId = notification.userInfo?["wheelId"] as? String
                {
                    print("🔗 WheelListView: Navigation requested to wheel: \(wheelId)")
                    handleDeepLinkWheel(wheelId: wheelId)
                } else {
                    print("🔗 WheelListView: Not a wheel navigation or no wheelId")
                }
            } else {
                print("🔗 WheelListView: No destination in notification")
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            CreateWheelFormView()
                .presentationDragIndicator(.visible)
        }
        .enableInjection()
    }

    // MARK: - Deep Link Handling

    private func checkAndHandleDeepLink() {
        print("🔗 WheelListView: ===== CHECKING PENDING DEEP LINK =====")
        if let wheelId = deepLinkService.getPendingWheelId() {
            print("🔗 WheelListView: ✅ Found pending wheel ID: \(wheelId)")
            handleDeepLinkWheel(wheelId: wheelId)
        } else {
            print("🔗 WheelListView: ❌ No pending wheel ID found")
        }
        print("🔗 WheelListView: ===== PENDING DEEP LINK CHECK COMPLETE =====")
    }

    private func handleDeepLinkWheel(wheelId: String) {
        print("🔗 WheelListView: Handling deep link to wheel: \(wheelId)")

        // Ищем колесо в загруженных данных
        let allWheels = viewModel.allWheels + viewModel.myWheels + viewModel.followingWheels
        print("🔗 WheelListView: Total wheels loaded: \(allWheels.count)")
        print("🔗 WheelListView: All wheels IDs: \(allWheels.map { $0.id })")

        if let wheel = allWheels.first(where: { $0.id == wheelId }) {
            // Если колесо найдено, открываем его
            print("🔗 WheelListView: Found wheel for deep link: \(wheel.name)")
            selectedWheel = wheel
            showingGame = true
            print("🔗 WheelListView: Set selectedWheel and showingGame = true")
        } else {
            // Если колесо не найдено, пытаемся загрузить его по ID
            print("🔗 WheelListView: Wheel not found in loaded data, trying to load by ID")
            Task {
                await loadWheelById(wheelId: wheelId)
            }
        }
    }

    private func loadWheelById(wheelId: String) async {
        print("🔗 WheelListView: Loading wheel by ID: \(wheelId)")

        // Здесь нужно добавить метод для загрузки колеса по ID
        // Пока что просто обновляем список колес
        await viewModel.refreshWheels()

        // После обновления проверяем снова
        DispatchQueue.main.async {
            let allWheels =
                self.viewModel.allWheels + self.viewModel.myWheels + self.viewModel.followingWheels
            if let wheel = allWheels.first(where: { $0.id == wheelId }) {
                self.selectedWheel = wheel
                self.showingGame = true
                print("🔗 WheelListView: Found wheel after refresh: \(wheel.name)")
            } else {
                print("🔗 WheelListView: Wheel not found after refresh: \(wheelId)")
            }
        }
    }
}

#Preview {
    WheelListView(user: nil)
}

// MARK: - Navigation Modifier
struct NavigationModifier: ViewModifier {
    @Binding var showingGame: Bool
    let selectedWheel: WheelWithRelations?
    let user: AuthResult?
    let isSidebarPreferred: Bool

    func body(content: Content) -> some View {
        if isSidebarPreferred {
            // Для iPad используем fullScreenCover на весь экран
            content
                .fullScreenCover(isPresented: $showingGame) {
                    if let wheel = selectedWheel {
                        NavigationStack {
                            FortuneWheelGameView(wheelData: wheel, currentUser: user?.user)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar(.hidden, for: .tabBar)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button("Закрыть") {
                                            showingGame = false
                                        }
                                        .foregroundColor(.white)
                                    }
                                }
                                .onAppear {
                                    print("🎮 WheelListView: Открыта игра для колеса: \(wheel.name)")
                                }
                        }
                    }
                }
        } else {
            // Для iPhone используем navigationDestination
            content
                .navigationDestination(isPresented: $showingGame) {
                    if let wheel = selectedWheel {
                        FortuneWheelGameView(wheelData: wheel, currentUser: user?.user)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar(.hidden, for: .tabBar)
                            .onAppear {
                                print("🎮 WheelListView: Открыта игра для колеса: \(wheel.name)")
                            }
                    }
                }
        }
    }
}
