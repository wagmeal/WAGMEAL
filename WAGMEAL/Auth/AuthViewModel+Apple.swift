import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Sign in with Apple

extension AuthViewModel {
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        let nonce = Self.randomNonceString()
        self.currentNonce = nonce
        let hashedNonce = Self.sha256(nonce)

        let appleIDCredential = try await Self.requestAppleCredential(
            presentationAnchor: presentationAnchor,
            hashedNonce: hashedNonce
        )

        guard let nonce = self.currentNonce else {
            throw NSError(domain: "Auth", code: -300, userInfo: [NSLocalizedDescriptionKey: "Missing nonce."])
        }

        guard let identityTokenData = appleIDCredential.identityToken else {
            throw NSError(domain: "Auth", code: -301, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token."])
        }
        guard let identityTokenString = String(data: identityTokenData, encoding: .utf8) else {
            throw NSError(domain: "Auth", code: -302, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize token string from data."])
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)

        let displayName = authResult.user.displayName
        let fullNameFromApple = [
            appleIDCredential.fullName?.familyName,
            appleIDCredential.fullName?.givenName
        ]
        .compactMap { $0 }
        .joined()

        let resolvedName = (displayName?.isEmpty == false ? displayName : nil)
            ?? (fullNameFromApple.isEmpty == false ? fullNameFromApple : nil)
            ?? (self.username?.isEmpty == false ? self.username : nil)
            ?? "名無し"

        let resolvedEmail = authResult.user.email ?? ""

        let uid = authResult.user.uid
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()

        if snap.exists {
            try await upsertUserProfile(
                uid: uid,
                username: resolvedName,
                email: resolvedEmail,
                birthday: nil,
                gender: nil
            )
        } else {
            try await upsertUserProfile(
                uid: uid,
                username: resolvedName,
                email: resolvedEmail,
                birthday: nil,
                gender: nil,
                profileCompleted: false
            )
            self.requiresProfileSetup = true
        }
    }

    private static func requestAppleCredential(
        presentationAnchor: ASPresentationAnchor,
        hashedNonce: String
    ) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { cont in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            let coordinator = AppleSignInCoordinator(
                presentationAnchor: presentationAnchor,
                continuation: cont
            )
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator

            coordinator.retainSelf()
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign-In Coordinator

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: ASPresentationAnchor
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var selfRetainer: AppleSignInCoordinator?

    init(
        presentationAnchor: ASPresentationAnchor,
        continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    ) {
        self.presentationAnchor = presentationAnchor
        self.continuation = continuation
    }

    func retainSelf() {
        selfRetainer = self
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer {
            continuation = nil
            selfRetainer = nil
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: NSError(domain: "Auth", code: -303, userInfo: [NSLocalizedDescriptionKey: "Invalid AppleID credential."]))
            return
        }
        continuation?.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer {
            continuation = nil
            selfRetainer = nil
        }
        continuation?.resume(throwing: error)
    }
}
