//
//  NotificationView.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import SwiftUI
import Inject

struct NotificationView: View {
    @ObserveInjection var inject
    let message: String
    let type: NotificationType
    let onDismiss: () -> Void

    @State private var isVisible = false

    enum NotificationType {
        case success
        case error

        var backgroundColor: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            }
        }

        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(.white)
                .font(.title3)

            Text(message)
                .foregroundColor(.white)
                .font(.body)
                .multilineTextAlignment(.leading)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.backgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }

            // Автоматически скрываем через 3 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
        .enableInjection()
    }
}

#Preview {
    VStack(spacing: 20) {
        NotificationView(
            message: "Сектор успешно удален",
            type: .success
        ) {
            print("Dismissed")
        }

        NotificationView(
            message: "Ошибка при удалении сектора",
            type: .error
        ) {
            print("Dismissed")
        }
    }
    .padding()
    .background(Color.black)
}
