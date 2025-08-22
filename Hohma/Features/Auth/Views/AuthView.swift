//
//  AuthView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import AuthenticationServices
import Inject
import SwiftUI

struct AuthView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: AuthViewModel
    @State private var showTelegramWebView = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Войти в Hohma")
                .font(.largeTitle)
                .bold()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            TelegramSignInButton {
                showTelegramWebView = true
            }
            .sheet(isPresented: $showTelegramWebView) {
                TelegramLoginWebView { token in
                    showTelegramWebView = false
                    viewModel.handleTelegramAuth(token: token)
                }
                #if os(macOS)
                    .frame(width: 800, height: 600)
                #endif
            }

            AppleSignInButton {
                viewModel.handleAppleAuth()
            }

        }
        .padding()
        .enableInjection()
    }
}
#Preview {
    AuthView(viewModel: AuthViewModel())
}
