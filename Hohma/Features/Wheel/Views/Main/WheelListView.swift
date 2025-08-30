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
    @State private var showingGame = false
    @State private var selectedWheel: WheelWithRelations?

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
                Task {
                    await viewModel.loadWheels()
                }
            }
            .refreshable {
                Task {

                    await viewModel.loadWheels()
                }

            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .appBackground()
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
                    await viewModel.refreshVisibleWheels()
                }
            }
        }
        .sheet(isPresented: $showingCreateForm) {
            CreateWheelFormView()
                .presentationDragIndicator(.visible)
        }
        .enableInjection()

    }
}

#Preview {
    WheelListView(user: nil)
}
