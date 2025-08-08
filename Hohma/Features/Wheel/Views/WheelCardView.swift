import AVFoundation
import Inject
import SwiftUI

struct WheelCardView: View {
    @ObserveInjection var inject
    @StateObject private var viewModel: WheelCardViewModel

    init(cardData: WheelWithRelations) {
        self._viewModel = StateObject(wrappedValue: WheelCardViewModel(cardData: cardData))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Видео фон с заголовком
            ZStack {
                if let player = viewModel.player {
                    VideoBackgroundView(player: player)
                        .frame(width: 380, height: 200)
                } else {
                    Color.gray
                        .frame(width: 380, height: 200)
                        .overlay(
                            Text("Нет видео")
                                .foregroundColor(.white)
                        )
                }

                WheelHeaderView(
                    hasWinner: viewModel.hasWinner,
                    winnerUser: viewModel.winnerUser
                )
            }

            // Информация о колесе
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.cardData.name)
                    .font(.body)
                    .fontWeight(.bold)
                    .padding(.bottom)

                if viewModel.hasParticipants {
                    Text("Участники")
                        .font(.body)
                        .fontWeight(.semibold)
                        .padding(.bottom)

                    ParticipantsView(users: viewModel.uniqueUsers)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom)
        }
        .background(Color("AccentColor").opacity(0.7))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 16)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        .frame(maxWidth: 380)
        .padding(.horizontal)
    }
}

#Preview {
    WheelCardView(cardData: .test)
}
