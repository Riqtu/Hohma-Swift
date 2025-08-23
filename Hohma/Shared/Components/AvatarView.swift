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
        AsyncImage(url: avatarUrl) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(fallbackColor)
            @unknown default:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(fallbackColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(borderColor, lineWidth: showBorder ? 1 : 0)
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
