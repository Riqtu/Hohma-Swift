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

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Колесо фортуны")
                        .font(.title)
                        .fontWeight(.semibold)

                    if viewModel.isLoading {
                        ProgressView()
                    } else if let error = viewModel.error, error.lowercased() != "cancelled" {
                        Text("Ошибка: \(error)")
                            .foregroundColor(.red)
                    } else {
                        ForEach(viewModel.wheels, id: \.id) { wheel in
                            WheelCardView(
                                cardData: wheel,
                                currentUser: user?.user
                            )
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
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .refreshable {
                print("⚡️ refreshable вызван")
                await Task {
                    await viewModel.refreshWheels()
                }.value
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wheelDataUpdated)) { _ in
            // Обновляем данные при изменении колеса (например, после игры)
            Task {
                await viewModel.refreshWheels()
            }
        }
        .enableInjection()
    }
}

#Preview {
    WheelListView(user: nil)
}
