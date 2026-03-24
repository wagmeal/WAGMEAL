//
//  DogFoodViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/13.
//
import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class DogFoodViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isSearchActive: Bool = false
    @Published var dogFoods: [DogFood] = []
    @Published var favoriteDogFoodIDs: Set<String> = []  // 🔸 追加
    @Published var selectedIngredientFilters: Set<IngredientFilter> = []
    // ブランド一覧から「すべて」を選択したときに全件表示するフラグ
    @Published var showAllFoodsFromBrandExplorer: Bool = false
    
    // 🔸 追加：評価件数キャッシュ（dogFoodID -> count）
    @Published private(set) var evaluationCounts: [String: Int] = [:]
    // 重複ロード防止
    private var loadingCountIDs: Set<String> = []
    
    private var useMockData: Bool
    private var favoritesListener: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init(mockData: Bool = false) {
        self.useMockData = mockData
        if mockData {
            loadMockDogFoods()
        } else {
            fetchDogFoods()
            
            // 🔸 ログイン状態を監視して購読の開始/停止を自動化
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self else { return }
                self.stopFavoritesListener()
                self.favoriteDogFoodIDs = []
                if let uid = user?.uid {
                    self.startFavoritesListener(for: uid)
                }
            }
        }
    }
    
    deinit {
        favoritesListener?.remove()
        if let h = authStateHandle {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }
    
    
    // MARK: - モックデータ
    private func loadMockDogFoods() {
        self.dogFoods = PreviewMockData.dogFood
    }
    
    // MARK: - ドッグフード一覧取得
    func fetchDogFoods() {
        let db = Firestore.firestore()
        
        db.collection("dogfood").getDocuments(source: .default) { snapshot, error in
            if let error = error {
                print("Firestore読み込みエラー: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            // どの項目が足りない/型が違うかを詳細ログ
            for doc in documents {
                let d = doc.data()
                var issues: [String] = []
                if d["name"] as? String == nil { issues.append("name:String") }
                if d["imagePath"] as? String == nil { issues.append("imagePath:String") }
                if d["description"] as? String == nil { issues.append("description:String") }
                if d["summary"] as? String == nil { issues.append("summary:String") }
                if d["ingredients"] as? String == nil { issues.append("ingredients:String") }
                if d["keywords"] as? [String] == nil { issues.append("keywords:[String]") }
                if !issues.isEmpty {
                    print("⚠️ \(doc.documentID) 欠落/型不一致 → \(issues)")
                }
            }
            
            let fetchedDogFoods: [DogFood] = documents.compactMap { doc -> DogFood? in
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let imagePath = data["imagePath"] as? String,
                    let description = data["description"] as? String,
                    let summary = data["summary"] as? String,
                    let keywords = data["keywords"] as? [String],
                    let ingredients = data["ingredients"] as? String
                else {
                    print("⚠️ データが不完全なためスキップ (ID: \(doc.documentID))")
                    return nil
                }
                let brand = data["brand"] as? String
                let homepageURL = data["homepageURL"] as? String
                let amazonURL = data["amazonURL"] as? String
                let yahooURL = data["yahooURL"] as? String
                let rakutenURL = data["rakutenURL"] as? String
                
                return DogFood(
                    id: doc.documentID,
                    name: name,
                    brand: brand,
                    imagePath: imagePath,
                    description: description,
                    summary: summary,
                    keywords: keywords,
                    ingredients: ingredients,
                    homepageURL: homepageURL,
                    amazonURL: amazonURL,
                    yahooURL: yahooURL,
                    rakutenURL: rakutenURL,
                    hasChicken: data["hasChicken"] as? Bool ?? false,
                    hasBeef: data["hasBeef"] as? Bool ?? false,
                    hasPork: data["hasPork"] as? Bool ?? false,
                    hasLamb: data["hasLamb"] as? Bool ?? false,
                    hasFish: data["hasFish"] as? Bool ?? false,
                    hasEgg: data["hasEgg"] as? Bool ?? false,
                    hasDairy: data["hasDairy"] as? Bool ?? false,
                    hasWheat: data["hasWheat"] as? Bool ?? false,
                    hasCorn: data["hasCorn"] as? Bool ?? false,
                    hasSoy: data["hasSoy"] as? Bool ?? false
                )
            }
            
            DispatchQueue.main.async {
                self.dogFoods = fetchedDogFoods
            }
        }
    }
    
    // MARK: - お気に入り（リアルタイム購読）
    func startFavoritesListener(for userID: String) {
        let db = Firestore.firestore()
        favoritesListener?.remove()
        
        favoritesListener = db.collection("users")
            .document(userID)
            .collection("favorites")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("❌ お気に入り購読エラー:", error.localizedDescription)
                    return
                }
                let ids = snapshot?.documents.map { $0.documentID } ?? []
                DispatchQueue.main.async {
                    self.favoriteDogFoodIDs = Set(ids)
                }
            }
    }
    
    func stopFavoritesListener() {
        favoritesListener?.remove()
        favoritesListener = nil
    }
    
    // MARK: - API（画面側はこれだけ使う）
    func isFavorite(_ dogFoodID: String?) -> Bool {
        guard let id = dogFoodID else { return false }
        return favoriteDogFoodIDs.contains(id)
    }
    
    func toggleFavorite(dogFoodID: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ 未ログイン：toggleFavoriteは無視")
            return
        }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
            .collection("favorites").document(dogFoodID)
        
        // UIの即時反映は listener に任せる（ここでは書き込みのみ）
        if favoriteDogFoodIDs.contains(dogFoodID) {
            ref.delete { err in
                if let err = err { print("❌ お気に入り削除エラー:", err.localizedDescription) }
            }
        } else {
            ref.setData(["createdAt": FieldValue.serverTimestamp()]) { err in
                if let err = err { print("❌ お気に入り追加エラー:", err.localizedDescription) }
            }
        }
    }
    
    /// キャッシュされた評価件数を返す（未取得なら nil）
       func evaluationCount(for id: String?) -> Int? {
           guard let id else { return nil }
           return evaluationCounts[id]
       }
    
    /// 未取得なら評価件数を取得してキャッシュに反映
        func loadEvaluationCountIfNeeded(for id: String?) {
            guard let id, !id.isEmpty else { return }
            // すでに持っている or ロード中ならスキップ
            if evaluationCounts[id] != nil || loadingCountIDs.contains(id) { return }

            loadingCountIDs.insert(id)
            let db = Firestore.firestore()
            let query = db.collection("evaluations").whereField("dogFoodId", isEqualTo: id)

            // ✅ 可能なら Aggregate Query を使用（課金効率・速度が良い）
            query.count.getAggregation(source: .server) { [weak self] snap, err in
                guard let self else { return }
                if let snap, err == nil {
                    let n = Int(truncating: snap.count) // Int64 -> Int
                    DispatchQueue.main.async {
                        self.evaluationCounts[id] = n
                        self.loadingCountIDs.remove(id)
                    }
                } else {
                    // フォールバック（Aggregate未対応やエラー時）：全件取得→count
                    query.getDocuments { [weak self] s, e in
                        guard let self else { return }
                        let n = s?.documents.count ?? 0
                        DispatchQueue.main.async {
                            self.evaluationCounts[id] = n
                            self.loadingCountIDs.remove(id)
                        }
                        if let e { print("⚠️ aggregate失敗のため fallback count。理由:", e.localizedDescription) }
                    }
                }
            }
        }
    
    /// まとめてプリフェッチ（画面表示直前に呼んでもOK）
        func prefetchEvaluationCounts(for ids: [String]) {
            for id in ids { loadEvaluationCountIfNeeded(for: id) }
        }
    
    // MARK: - 検索用
    var filteredDogFoods: [DogFood] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        return dogFoods.filter { food in
            // ① テキストマッチ
            let matchesText: Bool
            if lower.isEmpty {
                matchesText = true
            } else {
                let name = food.name.lowercased()
                let brand = food.brand?.lowercased() ?? ""
                matchesText = name.contains(lower) || brand.contains(lower)
            }

            // ② 成分フィルタ
            // selectedIngredientFilters は「除外したい成分」の集合として扱う
            let forbidden = selectedIngredientFilters
            let matchesIngredients: Bool
            if forbidden.isEmpty {
                // 何も除外していない → 成分では絞り込まない
                matchesIngredients = true
            } else {
                // 除外指定された成分を一つでも含むフードは表示しない
                let hasForbidden = forbidden.contains { filter in
                    food.contains(filter)
                }
                matchesIngredients = !hasForbidden
            }

            return matchesText && matchesIngredients
        }
    }
    
    /// UI用：全ドッグフードからブランド一覧を生成（重複排除・ケース非依存ソート）
    var allBrands: [String] {
        let arr = dogFoods.compactMap { $0.brand?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(arr)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// UI用：ブランドごとの件数
    var brandCounts: [String: Int] {
        var dict: [String: Int] = [:]
        for df in dogFoods {
            let key = df.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { continue }
            dict[key, default: 0] += 1
        }
        return dict
    }

    /// ブランド名で検索を発火
    func search(byBrand brand: String) {
        self.searchText = brand
        self.isSearchActive = true
    }
    
    // MARK: - Favorites タブ用（これを使えば専用VMなしでOK）
    var favoriteDogFoods: [DogFood] {
        dogFoods.filter { favoriteDogFoodIDs.contains($0.id ?? "") }
    }
    
    // MARK: - お気に入り取得
    func fetchFavorites(for userID: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).collection("favorites").getDocuments { snapshot, error in
            if let error = error {
                print("お気に入り取得エラー: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            self.favoriteDogFoodIDs = Set(documents.map { $0.documentID })
        }
    }
    
    // MARK: - お気に入り追加・削除
    func toggleFavorite(dogFoodID: String, userID: String) {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(userID).collection("favorites").document(dogFoodID)
        
        if favoriteDogFoodIDs.contains(dogFoodID) {
            // 削除
            ref.delete { error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.favoriteDogFoodIDs.remove(dogFoodID)
                    }
                } else {
                    print("お気に入り削除エラー: \(error!.localizedDescription)")
                }
            }
        } else {
            // 追加
            ref.setData(["createdAt": Timestamp()]) { error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.favoriteDogFoodIDs.insert(dogFoodID)
                    }
                } else {
                    print("お気に入り追加エラー: \(error!.localizedDescription)")
                }
            }
        }
    }
    
    
}

func saveEvaluation(_ evaluation: Evaluation, completion: @escaping (Bool) -> Void) {
    let db = Firestore.firestore()
    
    do {
        if let id = evaluation.id {
            // 既存IDがある場合は更新（または上書き保存）
            try db.collection("evaluations")
                .document(id)
                .setData(from: evaluation) { error in
                    completion(error == nil)
                }
        } else {
            // IDが未割当なら新規ドキュメントを自動生成
            _ = try db.collection("evaluations")
                .addDocument(from: evaluation) { error in
                    completion(error == nil)
                }
        }
    } catch {
        print("Error saving evaluation: \(error)")
        completion(false)
    }
}
