//
//  WheelCard.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct WheelListView: View {
    let user: AuthResult?
    @ObserveInjection var inject
    @StateObject private var viewModel: WheelListViewModel
    @State private var showingCreateForm = false
    @StateObject private var deepLinkService = DeepLinkService.shared

    @State private var showingGame = false
    @State private var selectedWheel: WheelWithRelations?
    @State private var wheelToShare: WheelWithRelations?
    @Environment(\.scenePhase) private var scenePhase

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Сегментированный контрол для фильтрации
            Picker("Фильтр", selection: $viewModel.selectedFilter) {
                Text("Все").tag(WheelFilter.all)
                Text("Мои").tag(WheelFilter.my)
                Text("Подписки").tag(WheelFilter.following)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: viewModel.selectedFilter) { oldValue, newValue in
                viewModel.loadWheels()
            }

            // Вертикальный список колес
            Group {
                if viewModel.isLoading && viewModel.wheels.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загрузка колес...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.wheels.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Колеса не найдены")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Создайте первое колесо или измените фильтры")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Создать колесо") {
                            showingCreateForm = true
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.wheels) { wheel in
                                WheelCardComponent(
                                    wheel: wheel,
                                    onTap: {
                                        selectedWheel = wheel
                                        showingGame = true
                                    },
                                    onDelete: {
                                        Task {
                                            await viewModel.deleteWheel(withId: wheel.id)
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                            }

                            if viewModel.hasMore {
                                Button(action: {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }) {
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                            .padding()
                                    } else {
                                        Text("Загрузка")
                                            .padding()
                                    }
                                }
                                .disabled(viewModel.isLoadingMore)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        await viewModel.refreshWheels()
                    }
                }
            }
            .onAppear {
                print("🔗 WheelListView: ===== VIEW APPEARED =====")
                viewModel.loadWheels()

                // Проверяем, есть ли pending deep link
                print("🔗 WheelListView: Checking for pending deep link...")
                checkAndHandleDeepLink()
                print("🔗 WheelListView: ===== VIEW APPEAR COMPLETE =====")
            }
            .onReceive(deepLinkService.$pendingWheelId) { wheelId in
                // Обрабатываем deep link когда он становится доступным
                if let wheelId = wheelId {
                    handleDeepLinkWheel(wheelId: wheelId)
                }
            }
        }
        .appBackground()
        .navigationTitle("Колесо фортуны")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateForm = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
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
                // Если ID нет, обновляем список колес без показа индикатора загрузки
                viewModel.loadWheels(showLoading: false)
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
        .fullScreenCover(isPresented: $showingCreateForm) {
            CreateWheelFormView()
        }
        .sheet(item: $wheelToShare) { wheel in
            ShareWheelToChatView(wheel: wheel) {
                wheelToShare = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareWheel)) { notification in
            if let wheel = notification.userInfo?["wheel"] as? WheelWithRelations {
                wheelToShare = wheel
            }
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
        let allWheels = viewModel.wheels
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
            let allWheels = self.viewModel.wheels
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
