import SwiftUI
import Inject

struct WheelHeaderView: View {
    @ObserveInjection var inject
    let hasWinner: Bool
    let winnerUser: AuthUser?

    var body: some View {
        ZStack {
            if hasWinner {
                WinnerView(winnerUser: winnerUser)
            } else {
                Text("Колесо фортуны")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        WheelHeaderView(hasWinner: true, winnerUser: AuthUser.mock)
        WheelHeaderView(hasWinner: false, winnerUser: nil)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
