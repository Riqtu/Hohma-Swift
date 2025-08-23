import AVFoundation
import Inject
import SwiftUI

struct WheelCardView: View {
    @ObserveInjection var inject
    @ObservedObject private var viewModel: WheelCardViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingGame = false

    let cardData: WheelWithRelations
    let currentUser: AuthUser?

    init(cardData: WheelWithRelations, currentUser: AuthUser? = nil) {
        self.cardData = cardData
        self.viewModel = WheelCardViewModel(cardData: cardData)
        self.currentUser = currentUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Видео фон с заголовком
            ZStack {
                if let urlString = cardData.theme?.backgroundVideoURL,
                    let url = URL(string: urlString)
                {
                    // Используем новый StreamVideoView для внешних URL
                    StreamVideoView(url: url)
                        .frame(width: 380, height: 200)
                        .clipped()
                        .id(urlString)  // Принудительно пересоздаем при изменении URL
                } else if viewModel.isVideoReady {
                    // Используем старый VideoBackgroundView для локального видео
                    if let player = viewModel.player {
                        VideoBackgroundView(player: player)
                            .frame(width: 380, height: 200)
                    }
                } else {
                    // Показываем градиент пока видео загружается
                    AnimatedGradientBackground()
                        .frame(width: 380, height: 200)
                }

                WheelHeaderView(
                    hasWinner: viewModel.hasWinner,
                    winnerUser: viewModel.winnerUser
                )
            }

            // Информация о колесе
            VStack(alignment: .leading, spacing: 10) {
                Text(cardData.name)
                    .font(.system(size: 20))
                    .fontWeight(.bold)
                    .padding(.bottom)

                if viewModel.hasParticipants {
                    Text("Участники")
                        .font(.body)
                        .fontWeight(.semibold)
                        .padding(.bottom, 10)

                    ParticipantsView(users: viewModel.uniqueUsers)
                }

                // Кнопка для запуска игры
                Button(action: {
                    showingGame = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Играть")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("AccentColor"))
                    .cornerRadius(8)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            // Не останавливаем видео при исчезновении карточки
            // viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.onScenePhaseChanged(newPhase)
        }
        .onChange(of: cardData.id) { _, _ in
            // Обновляем viewModel при изменении cardData
            print("🔄 Обновляем карточку: \(cardData.name)")
            viewModel.updateCardData(cardData)
        }
        .navigationDestination(isPresented: $showingGame) {
            FortuneWheelGameView(wheelData: cardData, currentUser: currentUser)
                .navigationBarTitleDisplayMode(.inline)

                .toolbar(.hidden, for: .tabBar)  // Скрываем TabBar в игре
            // .navigationBarBackButtonHidden(true)
        }
        .enableInjection()
    }
}

#Preview {
    WheelCardView(cardData: .test)
}
