import SwiftUI

struct ParticipantsView: View {
    let users: [AuthUser]
    let maxVisible: Int

    init(users: [AuthUser], maxVisible: Int = 5) {
        self.users = users
        self.maxVisible = maxVisible
    }

    private var visibleUsers: [AuthUser] {
        Array(users.prefix(maxVisible))
    }

    private var additionalCount: Int {
        max(0, users.count - maxVisible)
    }

    private var shouldShowAdditionalCount: Bool {
        users.count > maxVisible
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visibleUsers, id: \.id) { user in
                AvatarView(
                    avatarUrl: user.avatarUrl,
                    size: 40,
                    fallbackColor: .gray,
                    showBorder: false,
                    borderColor: .white
                )
            }

            if shouldShowAdditionalCount {
                Text("+\(additionalCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    ParticipantsView(users: [AuthUser.mock, AuthUser.mock])
        .padding()
        .background(Color.gray.opacity(0.2))
}
