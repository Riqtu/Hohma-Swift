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
        .enableInjection()
    }
}
#Preview {
    AuthView(viewModel: AuthViewModel())
}
