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

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
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
                    HStack {
                        Text("Колесо фортуны")
                            .font(.title)
                            .fontWeight(.semibold)

                        Spacer()

                        Button(action: {
                            showingCreateForm = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color("AccentColor"))
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = viewModel.error, error.lowercased() != "cancelled" {
                        Text("Ошибка: \(error)")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 375), spacing: 20)], spacing: 20
                        ) {
                            ForEach(viewModel.wheels, id: \.id) { wheel in
                                WheelCardView(
                                    cardData: wheel,
                                    currentUser: user?.user
                                )
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
                .padding()
                .onAppear {
                    Task {
                        // Загружаем данные только если список пустой
                        if viewModel.wheels.isEmpty {
                            await viewModel.loadWheels()
                        }
                    }
                }
            }
            .appBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { _ in
            // Обновляем данные при изменении колеса (например, после игры)
            Task {
                await viewModel.refreshWheels()
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
