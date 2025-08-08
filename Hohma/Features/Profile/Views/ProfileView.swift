import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Профиль пользователя")
                .font(.title)
                .fontWeight(.semibold)

            Text("Здесь будет информация о пользователе.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ProfileView()
}
