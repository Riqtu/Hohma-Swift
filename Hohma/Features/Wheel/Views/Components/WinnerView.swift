import Inject
import SwiftUI

struct WinnerView: View {
    @ObserveInjection var inject
    let winnerUser: AuthUser?

    var body: some View {
        if let winnerUser {
            AvatarView(
                avatarUrl: winnerUser.avatarUrl,
                size: 80,
                fallbackColor: .gray,
                showBorder: true,
                borderColor: .black
            )
        } else {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
        }
        ZStack {

        }
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        WinnerView(winnerUser: AuthUser.mock)
        WinnerView(winnerUser: nil)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
