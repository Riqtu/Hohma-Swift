import Inject
import SwiftUI

struct ParticipantRowView: View {
    @ObserveInjection var inject
    let user: AuthUser

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                avatarUrl: user.avatarUrl,
                userId: user.id,
                size: 50,
                fallbackColor: .gray,
                showBorder: true,
                borderColor: .white
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(user.coins)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.yellow)

                Text("монет")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .enableInjection()
    }
}

#Preview {
    ParticipantRowView(user: AuthUser.mock)
        .padding()
        .background(Color.black)
}
