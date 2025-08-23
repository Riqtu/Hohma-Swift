//
//  UsersPanelView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import Inject
import SwiftUI

struct UsersPanelView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: FortuneWheelViewModel
    let accentColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Участники (\(viewModel.roomUsers.count))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: accentColor))

                Spacer()

                // Индикатор подключения сокета
                Circle()
                    .fill(viewModel.isSocketReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .onAppear {
                print("👥 UsersPanelView: Appeared with \(viewModel.roomUsers.count) users")
            }
            .onChange(of: viewModel.roomUsers.count) { _, newCount in
                print("👥 UsersPanelView: Users count changed to \(newCount)")
            }

            if viewModel.roomUsers.isEmpty {
                VStack(spacing: 8) {
                    Text("Нет участников")
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !viewModel.isSocketReady {
                        Text("Подключение...")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyHStack(spacing: 8) {
                    ForEach(viewModel.roomUsers.prefix(8)) { user in
                        UserRowView(user: user, accentColor: accentColor)
                    }

                    if viewModel.roomUsers.count > 8 {
                        Text("+\(viewModel.roomUsers.count - 8) еще")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: accentColor).opacity(0.3), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.roomUsers.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSocketReady)
        .enableInjection()
    }
}

// #Preview {
//     UsersPanelView(
//         viewModel: FortuneWheelViewModel(...),
//         accentColor: "#F8D568"
//     )
//     .background(Color.black)
// }
