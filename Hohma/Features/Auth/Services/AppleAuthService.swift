//
//  AppleAuthService.swift
//  Hohma
//
//  Created by Artem Vydro on 06.08.2025.
//

import AuthenticationServices
import Foundation

@MainActor
class AppleAuthService: NSObject, ObservableObject {
    static let shared = AppleAuthService()
    private override init() {}

    @Published var isAuthenticating = false
    @Published var error: String?

    func signInWithApple() async -> AppleAuthRequest? {
        isAuthenticating = true
        error = nil

        #if DEBUG
            AppLogger.shared.debug("Apple Sign In: Starting authentication", category: .auth)
            AppLogger.shared.debug("Apple Sign In: Bundle ID = \(AppleSignInConfig.bundleId)", category: .auth)
            AppLogger.shared.debug("Apple Sign In: Client ID = \(AppleSignInConfig.clientId)", category: .auth)
        #endif

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        // Добавляем поддержку для симулятора
        #if targetEnvironment(simulator)
            AppLogger.shared.debug("Apple Sign In: Running on simulator", category: .auth)
        #endif

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self

        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            authorizationController.performRequests()
        }
    }

    private var authContinuation: CheckedContinuation<AppleAuthRequest?, Never>?
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            authContinuation?.resume(returning: nil)
            authContinuation = nil
            isAuthenticating = false
            return
        }

        let identityToken = appleIDCredential.identityToken
        let authorizationCode = appleIDCredential.authorizationCode

        guard let identityTokenString = String(data: identityToken!, encoding: .utf8) else {
            authContinuation?.resume(returning: nil)
            authContinuation = nil
            isAuthenticating = false
            return
        }

        let authorizationCodeString =
            authorizationCode != nil ? String(data: authorizationCode!, encoding: .utf8) : nil

        let appleUser = AppleUser(
            email: appleIDCredential.email,
            name: AppleUserName(
                firstName: appleIDCredential.fullName?.givenName,
                lastName: appleIDCredential.fullName?.familyName
            )
        )

        let request = AppleAuthRequest(
            identityToken: identityTokenString,
            authorizationCode: authorizationCodeString,
            user: appleUser
        )

        authContinuation?.resume(returning: request)
        authContinuation = nil
        isAuthenticating = false
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithError error: Error
    ) {
        self.error = error.localizedDescription
        authContinuation?.resume(returning: nil)
        authContinuation = nil
        isAuthenticating = false
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first
        else {
            return UIWindow()
        }
        return window
    }
}
