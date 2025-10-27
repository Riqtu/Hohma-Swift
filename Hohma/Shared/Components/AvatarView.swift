import Inject
import SwiftUI

struct AvatarView: View {
    @ObserveInjection var inject
    let avatarUrl: URL?
    let size: CGFloat
    let fallbackColor: Color
    let showBorder: Bool
    let borderColor: Color

    init(
        avatarUrl: URL?,
        size: CGFloat = 40,
        fallbackColor: Color = .gray,
        showBorder: Bool = true,
        borderColor: Color = .white
    ) {
        self.avatarUrl = avatarUrl
        self.size = size
        self.fallbackColor = fallbackColor
        self.showBorder = showBorder
        self.borderColor = borderColor
    }

    var body: some View {
        // Используем кэшированный компонент для лучшей производительности
        CachedAvatarView(
            userId: "unknown",  // Для общего AvatarView используем неизвестный ID
            avatarUrl: avatarUrl?.absoluteString,
            size: size,
            fallbackColor: fallbackColor,
            showBorder: showBorder,
            borderColor: borderColor
        )
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        AvatarView(avatarUrl: nil, size: 80, fallbackColor: .yellow)
        AvatarView(avatarUrl: nil, size: 40, fallbackColor: .gray)
    }
}
