import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UIKit

// MARK: - Google Sign-In

extension AuthViewModel {
    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        guard presentingViewController.view.window != nil else {
            let msg = "presentingViewController has no window (not visible). Pass a top-most visible VC."
            print("🧪 [GID] \(msg)")
            throw NSError(domain: "Diag", code: -200, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let app = FirebaseApp.app() else {
            let msg = "FirebaseApp.app() is nil. Did you call FirebaseApp.configure() in @main App.init()?"
            print("🧪 [GID] \(msg)")
            throw NSError(domain: "Diag", code: -201, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        print("🧪 [GID] FirebaseApp name:", app.name)

        guard let clientID = app.options.clientID, clientID.isEmpty == false else {
            let msg = "clientID not found. Check GoogleService-Info.plist Target Membership & Bundle ID match."
            print("🧪 [GID] \(msg)")
            throw NSError(domain: "Diag", code: -202, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        print("🧪 [GID] clientID:", clientID)

        let bundleID = Bundle.main.bundleIdentifier ?? "nil"
        let reversedClientID = Self.readPlistValue(forKey: "REVERSED_CLIENT_ID") ?? "nil"
        let urlSchemes = Self.currentURLSchemes()
        print("🧪 [GID] bundleID:", bundleID)
        print("🧪 [GID] REVERSED_CLIENT_ID from GoogleService-Info.plist:", reversedClientID)
        print("🧪 [GID] URL Schemes in Info.plist:", urlSchemes)

        if reversedClientID == "nil" {
            print("🧪 [GID][WARN] REVERSED_CLIENT_ID not found in GoogleService-Info.plist (old/invalid plist?)")
        } else if urlSchemes.contains(reversedClientID) == false {
            print("🧪 [GID][WARN] URL Types is missing REVERSED_CLIENT_ID. Add it to Target > Info > URL Types > URL Schemes.")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("🧪 [GID] Starting signIn(withPresenting: ...) ...")

        do {
            let signInResult: GIDSignInResult = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                    if let error = error {
                        let e = error as NSError
                        print("🧪 [GID] signIn callback error:", e.domain, e.code, e.localizedDescription, "userInfo:", e.userInfo)
                        cont.resume(throwing: error)
                        return
                    }
                    guard let result = result else {
                        let err = NSError(domain: "Diag", code: -203, userInfo: [NSLocalizedDescriptionKey: "signInResult is nil"])
                        print("🧪 [GID]", err.localizedDescription)
                        cont.resume(throwing: err)
                        return
                    }
                    cont.resume(returning: result)
                }
            }

            let user = signInResult.user
            print("🧪 [GID] signIn OK. has idToken? ->", user.idToken != nil, "has accessToken? ->", user.accessToken.tokenString.isEmpty == false)

            guard let idToken = user.idToken?.tokenString, idToken.isEmpty == false else {
                let msg = "idToken is nil/empty. (Did the callback return? URL handling / URL Types / Bundle ID mismatch?)"
                print("🧪 [GID] \(msg)")
                throw NSError(domain: "Diag", code: -204, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            let accessToken = user.accessToken.tokenString
            print("🧪 [GID] idToken.len:", idToken.count, "accessToken.len:", accessToken.count)

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            print("🧪 [GID] Signing in to Firebase ...")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("🧪 [GID] Firebase signIn OK. uid:", authResult.user.uid)

            let uid = authResult.user.uid
            let db = Firestore.firestore()
            let ref = db.collection("users").document(uid)
            let snap = try await ref.getDocument()

            if snap.exists {
                try await upsertUserProfile(
                    uid: uid,
                    username: authResult.user.displayName ?? self.username ?? "名無し",
                    email: authResult.user.email ?? "",
                    birthday: nil,
                    gender: nil
                )
            } else {
                try await upsertUserProfile(
                    uid: uid,
                    username: authResult.user.displayName ?? self.username ?? "名無し",
                    email: authResult.user.email ?? "",
                    birthday: nil,
                    gender: nil,
                    profileCompleted: false
                )
                self.requiresProfileSetup = true
            }

            print("🧪 [GID] upsertUserProfile done.")

        } catch {
            let e = error as NSError
            print("🧪 [GID] CATCH:", e.domain, e.code, e.localizedDescription, "userInfo:", e.userInfo)
            throw error
        }
    }

    func linkGoogle(presentingViewController: UIViewController) async throws {
        guard let current = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: -10, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "Auth", code: -11, userInfo: [NSLocalizedDescriptionKey: "clientID not found"])
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let signInResult: GIDSignInResult = try await withCheckedThrowingContinuation { cont in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let result = result else {
                    cont.resume(throwing: NSError(domain: "Auth", code: -12, userInfo: [NSLocalizedDescriptionKey: "No signInResult"]))
                    return
                }
                cont.resume(returning: result)
            }
        }

        let googleUser = signInResult.user
        guard let idToken = googleUser.idToken?.tokenString else {
            throw NSError(domain: "Auth", code: -13, userInfo: [NSLocalizedDescriptionKey: "No idToken"])
        }
        let accessToken = googleUser.accessToken.tokenString

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await current.link(with: credential)

        try await upsertUserProfile(
            uid: current.uid,
            username: current.displayName ?? self.username ?? "名無し",
            email: current.email ?? "",
            birthday: nil,
            gender: nil
        )
    }

    // MARK: - Diagnostics Helpers

    private static func currentURLSchemes() -> [String] {
        guard
            let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else { return [] }
        var schemes: [String] = []
        for item in types {
            if let s = item["CFBundleURLSchemes"] as? [String] {
                schemes.append(contentsOf: s)
            }
        }
        return schemes
    }

    private static func readPlistValue(forKey key: String) -> String? {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let value = dict[key] as? String {
            return value
        }
        return nil
    }
}
