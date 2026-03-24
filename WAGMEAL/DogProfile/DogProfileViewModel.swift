//
//  DogProfileViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

final class DogProfileViewModel: ObservableObject {
    @Published var dogs: [DogProfile] = []

    private let db = Firestore.firestore()
    private let isMock: Bool

    // 本番用
    init() {
        self.isMock = false
    }

    // モック用
    init(mockDogs: [DogProfile]) {
        self.isMock = true
        self.dogs = mockDogs
    }

    /// Firestoreからワンちゃん一覧を取得（モック時は何もしない）
    func fetchDogs(completion: (() -> Void)? = nil) {
        guard !isMock else {
            completion?()
            return
        }
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ ログインユーザーが見つかりません")
            completion?()
            return
        }

        db.collection("users")
            .document(userID)
            .collection("dogs")
            .order(by: "createdAt", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ ワンちゃんの取得に失敗: \(error.localizedDescription)")
                    completion?()
                    return
                }

                let fetched: [DogProfile] = snapshot?.documents.compactMap {
                    try? $0.data(as: DogProfile.self)
                } ?? []

                DispatchQueue.main.async {
                    // 🔥 isDeleted が true のものを除外してセットする！
                    self.dogs = fetched.filter { $0.isDeleted != true }
                    completion?()
                }
            }
    }

    /// ワンちゃんを論理削除（isDeleted = true にしてアプリ上は非表示）
    func softDelete(dog: DogProfile) {
        // モック環境：配列から削除して終了
        if isMock {
            if let dogID = dog.id {
                dogs.removeAll { $0.id == dogID }
            }
            return
        }

        guard
            let userID = Auth.auth().currentUser?.uid,
            let dogID = dog.id
        else {
            print("❌ softDelete 失敗: ユーザーIDまたはドキュメントIDがありません")
            return
        }

        let docRef = db
            .collection("users")
            .document(userID)
            .collection("dogs")
            .document(dogID)

        docRef.updateData(["isDeleted": true]) { [weak self] error in
            if let error = error {
                print("❌ softDelete 更新失敗: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self?.dogs.removeAll { $0.id == dogID }
            }
        }
    }

    /// ワンちゃん情報を更新（createdAtは保持、updatedAtのみ更新）
    func updateDog(_ updated: DogProfile, completion: ((Error?) -> Void)? = nil) {
        var newDog = updated
        newDog.updatedAt = Date()  // ← 最終更新日時を上書き

        // モック環境：配列のみ更新して終了
        if isMock {
            if let idx = dogs.firstIndex(where: { $0.id == updated.id }) {
                dogs[idx] = newDog
            }
            completion?(nil)
            return
        }

        guard
            let userID = Auth.auth().currentUser?.uid,
            let dogID = updated.id
        else {
            let err = NSError(domain: "DogProfileViewModel",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "ユーザーIDまたはドキュメントIDがありません"])
            completion?(err)
            return
        }

        do {
            try db.collection("users")
                .document(userID)
                .collection("dogs")
                .document(dogID)
                // 既存フィールド保持のため merge: true
                .setData(from: newDog, merge: true) { [weak self] error in
                    guard let self = self else { return }
                    if error == nil {
                        // ローカル配列も同期更新
                        if let idx = self.dogs.firstIndex(where: { $0.id == dogID }) {
                            DispatchQueue.main.async {
                                self.dogs[idx] = newDog
                            }
                        }
                    }
                    completion?(error)
                }
        } catch {
            completion?(error)
        }
    }
}
