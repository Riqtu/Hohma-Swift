import Inject
import SwiftUI

struct DeleteAccountButton: View {
    @ObserveInjection var inject
    @State private var showConfirmation = false
    let action: () -> Void
    let isLoading: Bool

    var body: some View {
        Button(action: {
            showConfirmation = true
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .medium))
                }

                Text(isLoading ? "Удаление..." : "Удалить аккаунт")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .alert("Удаление аккаунта", isPresented: $showConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                action()
            }
        } message: {
            Text(
                "Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить. Все ваши данные будут безвозвратно удалены."
            )
        }
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        DeleteAccountButton(
            action: { print("Delete account tapped") },
            isLoading: false
        )

        DeleteAccountButton(
            action: { print("Delete account tapped") },
            isLoading: true
        )
    }
    .padding()
}
