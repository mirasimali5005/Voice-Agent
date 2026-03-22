import Foundation
import AuthenticationServices
import SwiftUI

/// Manages Sign in with Apple authentication and persists credentials in the Keychain.
final class AuthManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated: Bool = false
    @Published var userId: String?
    @Published var userEmail: String?

    // MARK: - Keychain Keys

    private enum Keys {
        static let identityToken = "apple_identity_token"
        static let userId = "apple_user_id"
        static let userEmail = "apple_user_email"
    }

    // MARK: - Init

    override init() {
        super.init()
        checkExistingAuth()
    }

    // MARK: - Sign In

    /// Presents the native Sign in with Apple sheet.
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Sign Out

    /// Clears all stored credentials and resets published state.
    func signOut() {
        KeychainHelper.delete(key: Keys.identityToken)
        KeychainHelper.delete(key: Keys.userId)
        KeychainHelper.delete(key: Keys.userEmail)

        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.userId = nil
            self.userEmail = nil
        }
    }

    // MARK: - Check Existing Auth

    /// Restores authentication state from the Keychain on launch.
    func checkExistingAuth() {
        guard let tokenData = KeychainHelper.load(key: Keys.identityToken),
              !tokenData.isEmpty,
              let userIdData = KeychainHelper.load(key: Keys.userId),
              let storedUserId = String(data: userIdData, encoding: .utf8),
              !storedUserId.isEmpty
        else {
            isAuthenticated = false
            return
        }

        userId = storedUserId

        if let emailData = KeychainHelper.load(key: Keys.userEmail) {
            userEmail = String(data: emailData, encoding: .utf8)
        }

        isAuthenticated = true
    }

    // MARK: - Token Access

    /// Returns the stored identity token string, if available.
    var identityToken: String? {
        guard let data = KeychainHelper.load(key: Keys.identityToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private Helpers

    private func storeCredentials(identityToken: Data?, userId: String, email: String?) {
        if let token = identityToken {
            KeychainHelper.save(key: Keys.identityToken, data: token)
        }

        if let userIdData = userId.data(using: .utf8) {
            KeychainHelper.save(key: Keys.userId, data: userIdData)
        }

        if let email = email, let emailData = email.data(using: .utf8) {
            KeychainHelper.save(key: Keys.userEmail, data: emailData)
        }

        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.userId = userId
            self.userEmail = email
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let appleUserId = credential.user
        let email = credential.email
        let identityToken = credential.identityToken

        storeCredentials(identityToken: identityToken, userId: appleUserId, email: email)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("[AuthManager] Sign in with Apple failed: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window; fall back to creating one if needed
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
    }
}
