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

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
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
                PaginatedScrollView(
                    isLoadingMore: viewModel.isLoadingMore,
                    hasMoreData: viewModel.paginationInfo?.hasNextPage ?? false,
                    isRefreshing: viewModel.isRefreshing,
                    hasData: !viewModel.wheels.isEmpty,
                    onLoadMore: {
                        await viewModel.loadMoreWheels()
                    },
                    onRefresh: {
                        await viewModel.refreshWheels()
                    }
                ) {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let error = viewModel.error, error.lowercased() != "cancelled" {
                            Text("Ошибка: \(error)")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 375), spacing: 20)],
                                spacing: 20
                            ) {
                                ForEach(viewModel.wheels, id: \.id) { wheel in
                                    WheelCardView(
                                        cardData: wheel,
                                        currentUser: user?.user,
                                        onDelete: { wheelId in
                                            Task {
                                                await viewModel.deleteWheel(withId: wheelId)
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        if viewModel.isRefreshing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Обновление...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 10)  // Добавляем отступ сверху
                    .padding(.horizontal)
                    .padding(.bottom)
                    .onAppear {
                        Task {
                            // Загружаем данные только если список пустой
                            if viewModel.wheels.isEmpty {
                                await viewModel.loadWheels()
                            }
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .appBackground()

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
