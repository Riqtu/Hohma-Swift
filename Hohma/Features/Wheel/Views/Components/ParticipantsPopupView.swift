import SwiftUI

struct ParticipantsPopupView: View {
    let users: [AuthUser]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Участники")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.black.opacity(0.8))

                // Participants list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(users, id: \.id) { user in
                            ParticipantRowView(user: user)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black.opacity(0.9))
        }
        #if os(iOS)
            .navigationBarHidden(true)
        #endif
    }
}

#Preview {
    ParticipantsPopupView(users: [AuthUser.mock, AuthUser.mock])
        .background(Color.black)
}
