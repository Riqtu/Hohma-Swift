import SwiftUI
import Inject
struct ProfileView: View {
    @ObserveInjection var inject
    var body: some View {
        VStack(spacing: 20) {
            Text("Профиль пользователя")
                .font(.title)   
                .fontWeight(.semibold)

            Text("Здесь будет информация о пользователе.")
                .foregroundColor(.secondary)
        }
        .padding()
        .enableInjection()
    }
}

#Preview {
    ProfileView()
}
