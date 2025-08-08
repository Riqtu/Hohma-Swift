import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

class VideoPlayerView: UIView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        self.playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        self.playerLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = self.bounds
    }
}

struct VideoBackgroundView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = VideoPlayerView(player: player)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // frame обновится автоматически через layoutSubviews
    }
}


#elseif os(macOS)
import SwiftUI
import AVKit

struct VideoBackgroundView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = CALayer() // добавлено

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        view.layer?.addSublayer(playerLayer)

        DispatchQueue.main.async {
            player.play()
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer?.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = nsView.bounds
        }
    }
}
#endif
