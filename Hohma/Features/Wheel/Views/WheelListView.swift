//
//  WheelCard.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject
struct WheelListView: View {
    let user: AuthResult?
    @ObserveInjection var inject
    @StateObject private var viewModel: WheelListViewModel

    init(user: AuthResult?) {
        self.user = user
        _viewModel = StateObject(wrappedValue: WheelListViewModel(user: user))
    }

        var body: some View {
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
                            WheelCardView(cardData: wheel)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .onAppear {
                    Task {
                        await viewModel.loadWheels()
                    }
                }
            }
 
            .refreshable {
                print("⚡️ refreshable вызван")
                await Task {
                       await viewModel.loadWheels()
                   }.value
            }
            .enableInjection()
        }
}

#Preview {
    WheelListView(user: nil)
}
