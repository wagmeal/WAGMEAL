import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

// MARK: - Terms of Service

extension AuthViewModel {
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

            self.requiresTermsAgreement = false
            self.isLoggedIn = (self.user != nil)

            self.fetchUsernameFromFirestore(uid: currentUser.uid)

        } catch {
            print("❌ 規約同意情報の保存に失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - Account Deletion

extension AuthViewModel {
    /// アプリ内からアカウント削除を開始できるようにする（App Review 5.1.1(v) 対応）
    func deleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログインユーザーが見つかりません"])
        }

        let uid = currentUser.uid
        let db = Firestore.firestore()

        do {
            try await db.collection("users").document(uid).delete()

            try await deleteDocs(in: db.collection("dogs"), whereField: "ownerUid", equals: uid)
            try await deleteDocs(in: db.collection("dogs"), whereField: "userId", equals: uid)

            try await deleteDocs(in: db.collection("evaluations"), whereField: "userId", equals: uid)
            try await deleteDocs(in: db.collection("evaluations"), whereField: "uid", equals: uid)

            try await deleteDocs(in: db.collection("favorites"), whereField: "userId", equals: uid)
            try await deleteDocs(in: db.collection("favorites"), whereField: "uid", equals: uid)
        } catch {
            print("❌ Firestore データ削除でエラー: \(error.localizedDescription)")
        }

        do {
            try await currentUser.delete()
        } catch {
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError),
               authError.code == .requiresRecentLogin {
                throw NSError(
                    domain: "Auth",
                    code: nsError.code,
                    userInfo: [NSLocalizedDescriptionKey: "セキュリティのため再ログインが必要です。一度ログアウト→再ログイン後に、もう一度アカウント削除をお試しください。"]
                )
            }
            throw error
        }

        self.user = nil
        self.isLoggedIn = false
        self.username = nil
        self.requiresTermsAgreement = false
        self.requiresProfileSetup = false
    }

    private func deleteDocs(in collection: CollectionReference, whereField field: String, equals value: String) async throws {
        let snapshot = try await collection.whereField(field, isEqualTo: value).getDocuments()
        if snapshot.documents.isEmpty { return }

        var batch = Firestore.firestore().batch()
        var count = 0

        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
            count += 1

            if count == 450 {
                try await batch.commit()
                batch = Firestore.firestore().batch()
                count = 0
            }
        }

        if count > 0 {
            try await batch.commit()
        }
    }
}

// MARK: - Sign-out

extension AuthViewModel {
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        self.user = nil
        self.isLoggedIn = false
        self.username = nil
    }
}

// MARK: - Password Reset

extension AuthViewModel {
    func sendPasswordReset(email: String) async throws {
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
