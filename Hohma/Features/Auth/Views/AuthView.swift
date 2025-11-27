//
//  AuthView.swift
//  Hohma
//
//  Created by Artem Vydro on 05.08.2025.
//

import AuthenticationServices
import Inject
import SwiftUI
import UIKit

struct AuthView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: AuthViewModel
    @State private var showTelegramWebView = false
    @State private var showTermsWebView = false
    @State private var authMode: AuthMode = .login
    @State private var loginUsername: String = ""
    @State private var loginPassword: String = ""
    @State private var registerUsername: String = ""
    @State private var registerPassword: String = ""
    @State private var registerEmail: String = ""
    @State private var registerFirstName: String = ""
    @State private var registerLastName: String = ""

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

                credentialsCard

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

extension AuthView {
    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Способ авторизации", selection: $authMode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch authMode {
            case .login:
                loginForm
            case .register:
                registerForm
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var loginForm: some View {
        VStack(spacing: 12) {
            credentialField(
                title: "Логин",
                placeholder: "Введите логин",
                text: $loginUsername,
                systemImage: "person.circle"
            )

            credentialField(
                title: "Пароль",
                placeholder: "Введите пароль",
                text: $loginPassword,
                systemImage: "lock.fill",
                isSecure: true
            )

            Button {
                submitLogin()
            } label: {
                buttonLabel(title: "Войти")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitLogin || viewModel.isLoading)
        }
    }

    private var registerForm: some View {
        VStack(spacing: 12) {
            credentialField(
                title: "Логин",
                placeholder: "Укажите уникальный логин",
                text: $registerUsername,
                systemImage: "person.crop.circle.badge.plus"
            )

            credentialField(
                title: "Пароль",
                placeholder: "Минимум 8 символов",
                text: $registerPassword,
                systemImage: "lock.shield",
                isSecure: true
            )

            credentialField(
                title: "Email (опционально)",
                placeholder: "example@domain.com",
                text: $registerEmail,
                systemImage: "envelope",
                keyboardType: .emailAddress
            )

            HStack(spacing: 12) {
                credentialField(
                    title: "Имя",
                    placeholder: "Иван",
                    text: $registerFirstName,
                    systemImage: "textformat",
                    autocapitalization: .words
                )
                credentialField(
                    title: "Фамилия",
                    placeholder: "Иванов",
                    text: $registerLastName,
                    systemImage: "textformat.abc",
                    autocapitalization: .words
                )
            }

            Button {
                submitRegistration()
            } label: {
                buttonLabel(title: "Создать аккаунт")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitRegistration || viewModel.isLoading)
        }
    }

    @ViewBuilder
    private func credentialField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        systemImage: String,
        isSecure: Bool = false,
        autocapitalization: TextInputAutocapitalization = .never,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                if isSecure {
                    SecureField(placeholder, text: text)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                        .keyboardType(keyboardType)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func buttonLabel(title: String) -> some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var canSubmitLogin: Bool {
        !loginUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !loginPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSubmitRegistration: Bool {
        registerUsername.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && registerPassword.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    private func submitLogin() {
        viewModel.loginWithCredentials(
            username: loginUsername,
            password: loginPassword
        )
    }

    private func submitRegistration() {
        viewModel.registerWithCredentials(
            username: registerUsername,
            password: registerPassword,
            email: registerEmail,
            firstName: registerFirstName,
            lastName: registerLastName
        )
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login
    case register

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            return "Вход"
        case .register:
            return "Регистрация"
        }
    }
}
