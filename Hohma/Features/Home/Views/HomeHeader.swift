import SwiftUI
import AVFoundation
struct HomeHeader: View {
    let player = VideoPlayerManager.shared.player(resourceName: "background")

    var body: some View {
        ZStack {
            
            if let player {
                #if os(iOS)
                VideoBackgroundView(player: player)
                    .frame(height: 250)
                    .clipped()
                #elseif os(macOS)
                VideoBackgroundView(player: player)
                    .frame(height: 250)
                    .clipped()
                #endif
            }
            Color.black.opacity(0.4)
                .frame(height: 250)
                .blur(radius: 10)

            VStack(spacing: 10) {
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 24))      .foregroundColor(.white)

                Text("Приложение для своих.\nВсё, что важно — в одном месте.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .frame(height: 250)
    }
}

#Preview {
    HomeHeader()
}
