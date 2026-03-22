import SwiftUI
import AuthenticationServices

/// Full-screen login view shown before the main app when the user is not authenticated.
struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @Binding var skipAuth: Bool

    private let bgColor = Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.25), Color.red.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.red.opacity(0.9))
                }
                .padding(.bottom, 24)

                // Title
                Text("Voice Agent")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Sign in to sync your corrections\nand rules across devices")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 40)

                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        handleAuthorization(authorization)
                    case .failure(let error):
                        print("[LoginView] Sign in with Apple failed: \(error.localizedDescription)")
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(width: 260, height: 44)
                .cornerRadius(8)
                .padding(.bottom, 16)

                // Continue without account
                Button {
                    skipAuth = true
                } label: {
                    Text("Continue without account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                Text("Your data stays on this device only")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))

                Spacer()
            }
            .padding(40)
        }
        .preferredColorScheme(.dark)
        .frame(width: 620, height: 460)
    }

    // MARK: - Handle Authorization

    private func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let appleUserId = credential.user
        let email = credential.email
        let identityToken = credential.identityToken

        // Store via the shared AuthManager
        if let token = identityToken {
            KeychainHelper.save(key: "apple_identity_token", data: token)
        }
        if let data = appleUserId.data(using: .utf8) {
            KeychainHelper.save(key: "apple_user_id", data: data)
        }
        if let email = email, let data = email.data(using: .utf8) {
            KeychainHelper.save(key: "apple_user_email", data: data)
        }

        authManager.checkExistingAuth()
    }
}
