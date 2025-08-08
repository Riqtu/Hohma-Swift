//
//  AuthView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import SwiftUI

struct AuthView: View {
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
            
            Button("Войти через Telegram") {
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
        }
        .padding()
    }
}
#Preview {
    AuthView(viewModel: AuthViewModel())
}
