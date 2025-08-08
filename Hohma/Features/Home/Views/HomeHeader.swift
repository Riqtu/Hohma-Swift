import AVFoundation
import Inject
import SwiftUI

struct HomeHeader: View {
    @StateObject private var videoManager = VideoPlayerManager.shared
    @State private var player: AVPlayer?
    @Environment(\.scenePhase) private var scenePhase
    @ObserveInjection var inject

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
                    .font(.custom("Luckiest Guy", size: 24)).foregroundColor(.white)

                Text("Приложение для своих.\nВсё, что важно — в одном месте.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .frame(height: 250)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if player == nil {
                    setupPlayer()
                } else {
                    player?.play()
                }
            case .inactive, .background:
                player?.pause()
            @unknown default:
                break
            }
        }
        .enableInjection()
    }

    private func setupPlayer() {
        player = videoManager.player(resourceName: "background")
    }
}

#Preview {
    HomeHeader()
}
