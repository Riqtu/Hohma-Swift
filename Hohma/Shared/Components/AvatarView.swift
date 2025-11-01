import Inject
import SwiftUI

struct AvatarView: View {
    @ObserveInjection var inject
    let avatarUrl: URL?
    let userId: String?
    let size: CGFloat
    let fallbackColor: Color
    let showBorder: Bool
    let borderColor: Color

    init(
        avatarUrl: URL?,
        userId: String? = nil,
        size: CGFloat = 40,
        fallbackColor: Color = .gray,
        showBorder: Bool = true,
        borderColor: Color = .white
    ) {
        self.avatarUrl = avatarUrl
        self.userId = userId
        self.size = size
        self.fallbackColor = fallbackColor
        self.showBorder = showBorder
        self.borderColor = borderColor
    }

    var body: some View {
        // Используем кэшированный компонент для лучшей производительности
        CachedAvatarView(
            userId: userId ?? "unknown",  // Используем реальный userId если доступен, иначе "unknown"
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
