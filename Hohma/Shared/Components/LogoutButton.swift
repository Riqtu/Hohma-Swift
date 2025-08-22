import SwiftUI
import Inject

struct LogoutButton: View {
    @ObserveInjection var inject
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                
                Text("Выйти из системы")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(12)
        }
        .enableInjection()
    }
}

#Preview {
    LogoutButton {
        print("Logout tapped")
    }
    .padding()
}
