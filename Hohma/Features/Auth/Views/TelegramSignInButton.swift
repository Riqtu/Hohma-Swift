//
//  TelegramSignInButton.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import Inject
import SwiftUI

struct TelegramSignInButton: View {
    @ObserveInjection var inject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Войти через Telegram")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .enableInjection()
    }
}

#Preview {
    TelegramSignInButton {
        print("Telegram Sign In tapped")
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
