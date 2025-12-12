//
//  AppleSignInButton.swift
//  Hohma
//
//  Created by Artem Vhydro on 06.08.2025.
//

import SwiftUI
import Inject
import AuthenticationServices

struct AppleSignInButton: View {
    @ObserveInjection var inject
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Войти через Apple")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
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
    AppleSignInButton {
        AppLogger.shared.debug("Apple Sign In tapped", category: .auth)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
