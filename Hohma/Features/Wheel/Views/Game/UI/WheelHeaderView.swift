import Inject
import SwiftUI

struct WheelHeaderView: View {
    @ObserveInjection var inject
    let hasWinner: Bool
    let winnerUser: AuthUser?

    var body: some View {
        ZStack {
            if hasWinner {
                WinnerView(winnerUser: winnerUser)
            } else {
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 32))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .padding(.bottom, -10)

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
