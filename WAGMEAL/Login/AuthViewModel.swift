//
//  AuthViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - User Profile (username / birthday / gender)

    /// Firestore の users/{uid} からプロフィールを取得
    func loadUserProfile(completion: @escaping (_ username: String?, _ email: String?, _ birthday: Date?, _ gender: String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil, nil, nil, nil)
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ ユーザープロフィール取得エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, nil, nil, nil)
                }
                return
            }

            let data = snapshot?.data() ?? [:]
            let username = data["username"] as? String
            let email = data["email"] as? String
            let gender = data["gender"] as? String
            let birthdayTimestamp = data["birthday"] as? Timestamp
            let birthday = birthdayTimestamp?.dateValue()

            DispatchQueue.main.async {
                completion(username, email, birthday, gender)
            }
        }
    }

    /// ユーザープロフィール（ユーザー名・誕生日・性別）を更新
    func updateProfile(username: String, birthday: Date?, gender: String, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        guard let current = Auth.auth().currentUser else {
            let error = NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(false, error)
            return
        }

        Task {
            do {
                // Firestore の users/{uid} を更新
                try await self.upsertUserProfile(
                    uid: current.uid,
                    username: username,
                    email: current.email ?? "",
                    birthday: birthday,
                    gender: gender.isEmpty ? nil : gender
                )

                // FirebaseAuth の displayName も更新
                let changeRequest = current.createProfileChangeRequest()
                changeRequest.displayName = username
                try await changeRequest.commitChanges()

                await MainActor.run {
                    self.username = username
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    completion(false, error)
                }
            }
        }
    }
@Published var user: User?
@Published var isLoggedIn: Bool = false
@Published var username: String? = nil
@Published var requiresTermsAgreement: Bool = false

private let currentTermsVersion = 1

private var authStateListener: AuthStateDidChangeListenerHandle?

init() {
    setupAuthStateListener()
}

deinit {
    if let listener = authStateListener {
        Auth.auth().removeStateDidChangeListener(listener)
    }
}

private func setupAuthStateListener() {
    authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
        Task { @MainActor in
            guard let self = self else { return }
            self.user = user
            self.isLoggedIn = (user != nil)

            if let uid = user?.uid {
                self.fetchUsernameFromFirestore(uid: uid)
            } else {
                self.username = nil
            }
        }
    }
}

private func fetchUsernameFromFirestore(uid: String) {
    let db = Firestore.firestore()
    db.collection("users").document(uid).getDocument { snapshot, error in
        if let error = error {
            print("❌ ユーザー名取得エラー: \(error.localizedDescription)")
            return
        }

        guard let data = snapshot?.data() else {
            DispatchQueue.main.async {
                self.username = Auth.auth().currentUser?.displayName
                // ドキュメントが存在しない場合は規約未同意扱い
                self.requiresTermsAgreement = true
                self.isLoggedIn = false
            }
            return
        }

        let name = data["username"] as? String
        let termsVersion = data["agreedTermsVersion"] as? Int ?? 0

        DispatchQueue.main.async {
            if let name = name {
                self.username = name
            } else {
                self.username = Auth.auth().currentUser?.displayName
            }

            // 規約同意バージョンのチェック
            self.requiresTermsAgreement = (termsVersion < self.currentTermsVersion)
            if self.requiresTermsAgreement {
                // 規約未同意の場合はログイン状態を無効化
                self.isLoggedIn = false
            }
        }
    }
}

// MARK: - Email/Password

    /// ログイン用メールアドレス・パスワードの更新
    func updateLoginInfo(
        currentPassword: String,
        newEmail: String?,
        newPassword: String?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let user = Auth.auth().currentUser, let currentEmail = user.email else {
            let error = NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインユーザー情報が取得できません"])
            completion(false, error)
            return
        }

        // 変更項目が何もなければ何もしない
        if (newEmail == nil || newEmail?.isEmpty == true) &&
           (newPassword == nil || newPassword?.isEmpty == true) {
            completion(true, nil)
            return
        }

        // 現在のパスワードで再認証
        let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: currentPassword)

        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(false, error)
                return
            }

            // メールアドレス更新 → その後にパスワード更新、の順で処理
            func updateEmailIfNeeded(completion: @escaping (Error?) -> Void) {
                guard let newEmail = newEmail, !newEmail.isEmpty, newEmail != currentEmail else {
                    completion(nil)
                    return
                }

                user.updateEmail(to: newEmail) { error in
                    if let error = error {
                        completion(error)
                        return
                    }

                    // Firestore 側の email も更新しておく
                    let db = Firestore.firestore()
                    let ref = db.collection("users").document(user.uid)
                    ref.setData([
                        "email": newEmail,
                        "updatedAt": Timestamp(date: Date())
                    ], merge: true) { firestoreError in
                        if let firestoreError = firestoreError {
                            print("❌ Firestore email 更新エラー: \(firestoreError.localizedDescription)")
                        }
                        completion(nil) // Firestore 失敗は致命的ではないので処理は続行
                    }
                }
            }

            func updatePasswordIfNeeded(completion: @escaping (Error?) -> Void) {
                guard let newPassword = newPassword, !newPassword.isEmpty else {
                    completion(nil)
                    return
                }

                user.updatePassword(to: newPassword) { error in
                    completion(error)
                }
            }

            // 順番に実行
            updateEmailIfNeeded { emailError in
                if let emailError = emailError {
                    completion(false, emailError)
                    return
                }

                updatePasswordIfNeeded { passwordError in
                    if let passwordError = passwordError {
                        completion(false, passwordError)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        }
    }

func signIn(email: String, password: String) async throws {
    _ = try await Auth.auth().signIn(withEmail: email, password: password)
    // authStateListener が状態反映
}

func signUp(email: String, password: String, username: String, birthday: Date, gender: String) async throws {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)

    let changeRequest = result.user.createProfileChangeRequest()
    changeRequest.displayName = username
    try await changeRequest.commitChanges()

    try await upsertUserProfile(
        uid: result.user.uid,
        username: username,
        email: email,
        birthday: birthday,
        gender: gender
    )

    // 状態更新（listener に任せてもOK）
    self.user = result.user
    self.isLoggedIn = true
    self.username = username
}

// MARK: - Google Sign-In
func signInWithGoogle(presentingViewController: UIViewController) async throws {
    // ── 0) 前提チェック ──────────────────────────────────────────────
    // presentingVC が表示中か
    guard presentingViewController.view.window != nil else {
        let msg = "presentingViewController has no window (not visible). Pass a top-most visible VC."
        print("🧪 [GID] \(msg)")
        throw NSError(domain: "Diag", code: -200, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    // FirebaseApp
    guard let app = FirebaseApp.app() else {
        let msg = "FirebaseApp.app() is nil. Did you call FirebaseApp.configure() in @main App.init()?"
        print("🧪 [GID] \(msg)")
        throw NSError(domain: "Diag", code: -201, userInfo: [NSLocalizedDescriptionKey: msg])
    }
    print("🧪 [GID] FirebaseApp name:", app.name)

    // clientID
    guard let clientID = app.options.clientID, clientID.isEmpty == false else {
        let msg = "clientID not found. Check GoogleService-Info.plist Target Membership & Bundle ID match."
        print("🧪 [GID] \(msg)")
        throw NSError(domain: "Diag", code: -202, userInfo: [NSLocalizedDescriptionKey: msg])
    }
    print("🧪 [GID] clientID:", clientID)

    // Bundle ID / URL Types / REVERSED_CLIENT_ID を診断
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

    // ── 1) Google Sign-In 起動 ───────────────────────────────────────
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

        // ── 2) idToken / accessToken 確認 ─────────────────────────────
        guard let idToken = user.idToken?.tokenString, idToken.isEmpty == false else {
            let msg = "idToken is nil/empty. (Did the callback return? URL handling / URL Types / Bundle ID mismatch?)"
            print("🧪 [GID] \(msg)")
            throw NSError(domain: "Diag", code: -204, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let accessToken = user.accessToken.tokenString
        print("🧪 [GID] idToken.len:", idToken.count, "accessToken.len:", accessToken.count)

        // ── 3) Firebase Auth へブリッジ ──────────────────────────────
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        print("🧪 [GID] Signing in to Firebase ...")
        let authResult = try await Auth.auth().signIn(with: credential)
        print("🧪 [GID] Firebase signIn OK. uid:", authResult.user.uid)

        // ── 4) Firestoreプロフィール Upsert（任意実装）────────────────
        try await upsertUserProfile(
            uid: authResult.user.uid,
            username: authResult.user.displayName ?? self.username ?? "名無し",
            email: authResult.user.email ?? "",
            birthday: nil,
            gender: nil
        )
        print("🧪 [GID] upsertUserProfile done.")

    } catch {
        let e = error as NSError
        print("🧪 [GID] CATCH:", e.domain, e.code, e.localizedDescription, "userInfo:", e.userInfo)
        throw error
    }
}

// MARK: - Terms of Service Agreement
func agreeToCurrentTerms() async {
    guard let currentUser = Auth.auth().currentUser else {
        print("❌ 規約同意処理: ログインユーザーが見つかりません")
        return
    }

    let db = Firestore.firestore()
    let ref = db.collection("users").document(currentUser.uid)
    let now = Timestamp(date: Date())

    do {
        try await ref.setData([
            "agreedTermsVersion": currentTermsVersion,
            "agreedAt": now,
            "updatedAt": now
        ], merge: true)

        // 規約同意済みとしてフラグ更新
        self.requiresTermsAgreement = false
        // すでに FirebaseAuth 的にはログインしているので、アプリ側のログイン状態も有効化
        self.isLoggedIn = (self.user != nil)
    } catch {
        print("❌ 規約同意情報の保存に失敗: \(error.localizedDescription)")
    }
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
    // バンドル内の GoogleService-Info.plist を直接読む（存在確認 & REVERSED_CLIENT_ID 抽出）
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
       let value = dict[key] as? String {
        return value
    }
    return nil
}

/// 既存アカウントに Google をリンク（任意）
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

    // リンク後もプロフィール整合性を保つ
    try await upsertUserProfile(
        uid: current.uid,
        username: current.displayName ?? self.username ?? "名無し",
        email: current.email ?? "",
        birthday: nil,
        gender: nil
    )
}

// MARK: - Sign-out
func signOut() throws {
    try Auth.auth().signOut()
    GIDSignIn.sharedInstance.signOut() // ★ Google セッションも明示的に終了
    self.user = nil
    self.isLoggedIn = false
    self.username = nil
}

func logout() {
    do {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut() // ★
        self.user = nil
        self.isLoggedIn = false
        self.username = nil
    } catch {
        print("ログアウト失敗: \(error.localizedDescription)")
    }
}

// MARK: - Private
/// users/{uid} を作成 or 更新（初回Googleログイン時の穴埋めにも）
private func upsertUserProfile(uid: String, username: String, email: String, birthday: Date? = nil, gender: String? = nil) async throws {
    let db = Firestore.firestore()
    let ref = db.collection("users").document(uid)
    let now = Timestamp(date: Date())

    var baseData: [String: Any] = [
        "username": username,
        "email": email,
        "updatedAt": now
    ]

    if let birthday = birthday {
        baseData["birthday"] = Timestamp(date: birthday)
    }
    if let gender = gender {
        baseData["gender"] = gender
    }

    // 既存を見て upsert
    let snapshot = try await ref.getDocument()
    if snapshot.exists {
        try await ref.setData(baseData, merge: true)
    } else {
        baseData["id"] = uid
        baseData["createdAt"] = now
        try await ref.setData(baseData)
    }
    // ローカル状態にも反映
    self.username = username
}
}

extension AuthViewModel {
/// パスワード再設定メールを送信
func sendPasswordReset(email: String) async throws {
    // 日本語メールにしたい場合（※送る直前に設定）
    Auth.auth().languageCode = "ja"

    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: ())
            }
        }
    }
}
}
