//
//  AuthViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseCore

@MainActor
class AuthViewModel: ObservableObject {
    var currentNonce: String?
    private nonisolated static var isRunningPreviews: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }
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
    func updateProfile(username: String, birthday: Date?, gender: String?, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
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
                    gender: (gender?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : gender,
                    profileCompleted: true
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
@Published var requiresProfileSetup: Bool = false

let currentTermsVersion = 1

private var authStateListener: AuthStateDidChangeListenerHandle?

init() {
    // SwiftUI Preview では FirebaseApp.configure() が呼ばれないため FirebaseAuth を触るとクラッシュする
    if Self.isRunningPreviews {
        self.user = nil
        self.isLoggedIn = false
        self.username = nil
        self.requiresTermsAgreement = false
        self.requiresProfileSetup = false
        return
    }

    setupAuthStateListener()
}

deinit {
    guard Self.isRunningPreviews == false else { return }
    if let listener = authStateListener {
        Auth.auth().removeStateDidChangeListener(listener)
    }
}

private func setupAuthStateListener() {
    guard Self.isRunningPreviews == false else { return }
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

    func fetchUsernameFromFirestore(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ ユーザー名取得エラー: \(error.localizedDescription)")
                return
            }

            // 🔴 ドキュメントがまだない場合（初回ログイン直後など）
            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.username = Auth.auth().currentUser?.displayName
                    // ドキュメントが存在しない場合は規約未同意扱い
                    self.requiresTermsAgreement = true
                    self.isLoggedIn = false

                    // ★ プロフィールも当然未登録なので true にしておく
                    self.requiresProfileSetup = true
                }
                return
            }

            // 🔵 ドキュメントがある場合
            let name = data["username"] as? String
            let termsVersion = data["agreedTermsVersion"] as? Int ?? 0
            let profileCompleted = data["profileCompleted"] as? Bool ?? true
            // 既存ユーザー互換：フィールドが無い人は「完了扱い」にする（強制遷移しない）

            DispatchQueue.main.async {
                // ユーザー名の設定
                if let name = name, !name.isEmpty {
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

                let currentName = self.username ?? ""
                let needsProfile =
                    (profileCompleted == false) ||
                    currentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                self.requiresProfileSetup = needsProfile
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

                // ⚠️ FirebaseAuth の updateEmail は非推奨。
                // ユーザーに確認メールを送って、リンク踏破後に email が更新される方式に変更。
                user.sendEmailVerification(beforeUpdatingEmail: newEmail) { error in
                    if let error = error {
                        completion(error)
                        return
                    }

                    // Firestore は「確定 email」ではなく、申請中として保存しておく
                    // （確認リンクを踏むまでは Auth.user.email は変わらないため）
                    let db = Firestore.firestore()
                    let ref = db.collection("users").document(user.uid)
                    ref.setData([
                        "pendingEmail": newEmail,
                        "pendingEmailRequestedAt": Timestamp(date: Date()),
                        "updatedAt": Timestamp(date: Date())
                    ], merge: true) { firestoreError in
                        if let firestoreError = firestoreError {
                            print("❌ Firestore pendingEmail 更新エラー: \(firestoreError.localizedDescription)")
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

                // NOTE: email 変更は確認リンク踏破後に反映される。
                // ここでは「確認メール送信まで成功」扱いでパスワード更新に進む。

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

    func signUp(email: String, password: String, username: String, birthday: Date?, gender: String?) async throws {
    let result = try await Auth.auth().createUser(withEmail: email, password: password)

    let changeRequest = result.user.createProfileChangeRequest()
    changeRequest.displayName = username
    try await changeRequest.commitChanges()

    try await upsertUserProfile(
        uid: result.user.uid,
        username: username,
        email: email,
        birthday: birthday,
        gender: gender,
        profileCompleted: true
    )

    // 状態更新（listener に任せてもOK）
    self.user = result.user
    self.isLoggedIn = true
    self.username = username
}


// MARK: - Private
/// users/{uid} を作成 or 更新（初回ソーシャルログイン時の穴埋めにも）
func upsertUserProfile(
    uid: String,
    username: String,
    email: String,
    birthday: Date? = nil,
    gender: String? = nil,
    profileCompleted: Bool? = nil
) async throws {
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
    if let profileCompleted = profileCompleted {
        baseData["profileCompleted"] = profileCompleted
    }

    // 既存を見て upsert
    let snapshot = try await ref.getDocument()
    if snapshot.exists {
        try await ref.setData(baseData, merge: true)
    } else {
        baseData["id"] = uid
        baseData["createdAt"] = now
        if baseData["profileCompleted"] == nil {
            baseData["profileCompleted"] = false
        }
        try await ref.setData(baseData)
    }
    // ローカル状態にも反映
    self.username = username
}
}

