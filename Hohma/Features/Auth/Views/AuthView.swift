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
    @State private var showTermsWebView = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background image at the very top
            Image("bulb")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(.all, edges: .top)

            // Main content
            VStack(spacing: 20) {
                Spacer()
                Text("XOXMA")
                    .font(.custom("Luckiest Guy", size: 40))
                    .bold()
                Text("Добро пожаловать!")
                    .font(.title2)
                    .bold()

                Spacer()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                // Ссылка на условия использования
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Авторизуясь, вы соглашаетесь с")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    Button("Условиями использования") {
                        showTermsWebView = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .underline()
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)

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
        }
        .sheet(isPresented: $showTermsWebView) {
            if let url = URL(string: "https://hohma.su/terms-of-service") {
                WebViewSheet(url: url, title: "Условия использования")
            }
        }
        .enableInjection()
    }
}
#Preview {
    AuthView(viewModel: AuthViewModel())
}
