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

// MARK: - Filter Models (Food Type & Nutrients)

enum FoodTypeFilter: String, CaseIterable, Identifiable, Codable {
    case all
    case dry
    case wet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "すべて"
        case .dry: return "ドライのみ"
        case .wet: return "ウェットのみ"
        }
    }
}

/// 成分数値フィルタ（範囲指定）
/// - isEnabled == false のときは未適用
/// - minValue / maxValue が nil の場合はその側の条件なし
struct NumericFilter: Codable, Hashable {
    var isEnabled: Bool = false
    var minValue: Double? = nil
    var maxValue: Double? = nil

    init(isEnabled: Bool = false, minValue: Double? = nil, maxValue: Double? = nil) {
        self.isEnabled = isEnabled
        self.minValue = minValue
        self.maxValue = maxValue
    }

    static func disabled() -> NumericFilter {
        .init(isEnabled: false, minValue: nil, maxValue: nil)
    }
}

class DogFoodViewModel: ObservableObject {
    // MARK: - Preview判定（Xcode PreviewsではFirebase/Networkを叩かない）
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    @Published var searchText: String = ""
    @Published var isSearchActive: Bool = false
    @Published var dogFoods: [DogFood] = []
    // 🔸 追加：検索タブで開いているドッグフード（外部画面からもセットして遷移に使う）
    @Published var selectedDogFood: DogFood? = nil
    @Published var favoriteDogFoodIDs: Set<String> = []
    // お気に入り登録日時（createdAt降順ソート用）。@Publishedは不要—favoriteDogFoodIDsの更新で同時に書き換わるため
    private var favoriteCreatedAts: [String: Date] = [:]
    @Published var selectedIngredientFilters: Set<IngredientFilter> = []
    // 「含む」フィルタ（この成分が入っているフードに絞り込む）
    @Published var includeIngredientFilters: Set<IngredientFilter> = []
    // ブランド一覧から「すべて」を選択したときに全件表示するフラグ
    @Published var showAllFoodsFromBrandExplorer: Bool = false
    
    // MARK: - 追加：フード種類フィルタ
    @Published var foodTypeFilter: FoodTypeFilter = .all

    // MARK: - 追加：成分数値フィルタ（範囲指定・未適用は isEnabled=false）
    @Published var caloriesFilter: NumericFilter = .disabled()
    @Published var proteinFilter: NumericFilter = .disabled()
    @Published var fatFilter: NumericFilter = .disabled()
    @Published var fiberFilter: NumericFilter = .disabled()
    @Published var ashFilter: NumericFilter = .disabled()
    @Published var moistureFilter: NumericFilter = .disabled()
    
    // フード一覧の初期ロード状態（FavoritesViewのスピナー制御に使用）
    @Published private(set) var isLoading: Bool = false

    // 🔸 追加：評価件数キャッシュ（dogFoodID -> count）
    @Published private(set) var evaluationCounts: [String: Int] = [:]
    // 重複ロード防止
    private var loadingCountIDs: Set<String> = []
    
    func resetEvaluationCountCache(only ids: [String]) {
        for id in ids {
            evaluationCounts.removeValue(forKey: id)
            loadingCountIDs.remove(id) // ← これは “そのIDだけ” ならOK
        }
    }
    
    private var useMockData: Bool
    private var favoritesListener: ListenerRegistration?
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init(mockData: Bool = false) {
        // Previewsでは必ずモック（Firestore/Auth/Networkを触らない）
        if Self.isPreview {
            self.useMockData = true
            loadMockDogFoods()
            return
        }

        self.useMockData = mockData
        if mockData {
            loadMockDogFoods()
        } else {
            fetchDogFoods()

            // 🔸 ログイン状態を監視して購読の開始/停止を自動化
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.stopFavoritesListener()
                    self.favoriteDogFoodIDs = []
                    if let uid = user?.uid {
                        self.startFavoritesListener(for: uid)
                    }
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
        self.favoriteDogFoodIDs = Set(PreviewMockData.favoriteIds(for: "user_001"))
        // プレビューでも createdAt 順を再現するためモックの登録日時を設定
        var mockCreatedAts: [String: Date] = [:]
        for fav in PreviewMockData.favorites where fav.userId == "user_001" {
            mockCreatedAts[fav.dogFoodId] = fav.createdAt
        }
        self.favoriteCreatedAts = mockCreatedAts
    }
    
    // MARK: - ドッグフード一覧取得
    func fetchDogFoods() {
        guard !Self.isPreview else { return }
        isLoading = true
        let db = Firestore.firestore()

        db.collection("dogfood").getDocuments(source: .default) { snapshot, error in
            if let error = error {
                print("Firestore読み込みエラー: \(error.localizedDescription)")
                Task { @MainActor in self.isLoading = false }
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            #if DEBUG
            // Debugビルドのみ：どの項目が足りない/型が違うかを詳細ログ
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
            #endif
            
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
                let storagePath = data["storagePath"] as? String
                let brand = data["brand"] as? String
                let homepageURL = data["homepageURL"] as? String
                let amazonURL = data["amazonURL"] as? String
                let yahooURL = data["yahooURL"] as? String
                let rakutenURL = data["rakutenURL"] as? String

                // --- New fields (foodType & nutrients) ---
                let foodType = (data["foodType"] as? String).flatMap { DogFoodType(rawValue: $0) }

                func readDouble(_ key: String) -> Double? {
                    if let d = data[key] as? Double { return d }
                    if let i = data[key] as? Int { return Double(i) }
                    if let s = data[key] as? String {
                        // "23%" / "23.0" / "370kcal" などを許容
                        let cleaned = s
                            .replacingOccurrences(of: "%", with: "")
                            .replacingOccurrences(of: "kcal", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return Double(cleaned)
                    }
                    return nil
                }

                let protein = readDouble("protein")
                let fat = readDouble("fat")
                let fiber = readDouble("fiber")
                let ash = readDouble("ash")
                let moisture = readDouble("moisture")
                let calories = readDouble("calories")

                return DogFood(
                    id: doc.documentID,
                    name: name,
                    brand: brand,
                    imagePath: imagePath,
                    storagePath: storagePath,
                    foodType: foodType,
                    protein: protein,
                    fat: fat,
                    fiber: fiber,
                    ash: ash,
                    moisture: moisture,
                    calories: calories,
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
            
            Task { @MainActor in
                self.dogFoods = fetchedDogFoods
                self.isLoading = false
            }
        }
    }
    
    // MARK: - お気に入り（リアルタイム購読）
    func startFavoritesListener(for userID: String) {
        guard !Self.isPreview else { return }
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
                let docs = snapshot?.documents ?? []
                let ids = Set(docs.map { $0.documentID })
                // createdAt を取得してソートに使う（フィールドがない場合は epoch を使用）
                var createdAts: [String: Date] = [:]
                for doc in docs {
                    createdAts[doc.documentID] = (doc.data()["createdAt"] as? Timestamp)?.dateValue()
                        ?? Date(timeIntervalSince1970: 0)
                }
                Task { @MainActor in
                    self.favoriteDogFoodIDs = ids
                    self.favoriteCreatedAts = createdAts
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
        guard !Self.isPreview else { return }
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
    
    
    // MARK: - 検索タブ用リセット
    func resetSearchState() {
        resetSearchUIStateKeepingFilters()
        includeIngredientFilters.removeAll()
        selectedIngredientFilters.removeAll()
        // selectedDogFoodはresetSearchUIStateKeepingFilters()でクリアされるのでここで再度クリア不要
    }
    
    /// 検索UIを初期状態（未入力・ブランド一覧表示）に戻す。
    /// ただし成分フィルター（include / exclude）は維持する。
    func resetSearchUIStateKeepingFilters() {
        searchText = ""
        isSearchActive = false
        showAllFoodsFromBrandExplorer = false
        selectedDogFood = nil

        // ✅ フィルタは維持する（ここでは触らない）
        // includeIngredientFilters / selectedIngredientFilters はそのまま
    }
    
    /// キャッシュされた評価件数を返す（未取得なら nil）
       func evaluationCount(for id: String?) -> Int? {
           guard let id else { return nil }
           return evaluationCounts[id]
       }
    
    /// 未取得なら評価件数を取得してキャッシュに反映
        func loadEvaluationCountIfNeeded(for id: String?) {
            guard !Self.isPreview else { return }
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
                    Task { @MainActor in
                        self.evaluationCounts[id] = n
                        self.loadingCountIDs.remove(id)
                    }
                } else {
                    // フォールバック（Aggregate未対応やエラー時）：全件取得→count
                    query.getDocuments { [weak self] s, e in
                        guard let self else { return }
                        let n = s?.documents.count ?? 0
                        Task { @MainActor in
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
    
    private func matchesFoodType(_ food: DogFood) -> Bool {
        switch foodTypeFilter {
        case .all: return true
        case .dry: return food.foodType == .dry
        case .wet: return food.foodType == .wet
        }
    }

    private func matchesNumeric(_ value: Double?, filter: NumericFilter) -> Bool {
        // 未適用なら常にOK
        guard filter.isEnabled else { return true }

        // 値が無いものは除外（範囲を指定しているのに値が無い場合）
        guard let v = value else { return false }

        if let minV = filter.minValue, v < minV { return false }
        if let maxV = filter.maxValue, v > maxV { return false }
        return true
    }
    
    // MARK: - 検索用
    var filteredDogFoods: [DogFood] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        return dogFoods.filter { food in
            // ① テキストマッチ
            // 複数ワード入力（例："ブランド名 フード名"）にも対応。
            // 入力を空白で分割し、各トークンが「名前 or ブランド」のどちらかに含まれていれば一致とする（AND条件）。
            let matchesText: Bool
            if lower.isEmpty {
                matchesText = true
            } else {
                let name = food.name.lowercased()
                let brand = food.brand?.lowercased() ?? ""
                let tokens = lower
                    .split(whereSeparator: { $0.isWhitespace })
                    .map { String($0) }
                    .filter { !$0.isEmpty }

                // 1ワードなら従来通り（OR）
                if tokens.count <= 1, let t = tokens.first {
                    matchesText = name.contains(t) || brand.contains(t)
                } else {
                    // 複数ワードは AND（各トークンが name/brand のどちらかに入っている）
                    matchesText = tokens.allSatisfy { token in
                        name.contains(token) || brand.contains(token)
                    }
                }
            }

            // ② 成分フィルタ
            // - includeIngredientFilters: 「含む」(AND条件: すべて含む)
            // - selectedIngredientFilters: 「含まない」(除外: どれも含まない)
            let include = includeIngredientFilters
            let exclude = selectedIngredientFilters

            // 「含む」：include に入っている成分はすべて含んでいる必要がある
            let includeOK = include.allSatisfy { filter in
                food.contains(filter)
            }

            // 「含まない」：exclude に入っている成分は1つも含んではいけない
            let excludeOK = exclude.allSatisfy { filter in
                !food.contains(filter)
            }

            let matchesIngredients = includeOK && excludeOK

            let matchesNewFilters =
                matchesFoodType(food)
                && matchesNumeric(food.calories, filter: caloriesFilter)
                && matchesNumeric(food.protein, filter: proteinFilter)
                && matchesNumeric(food.fat, filter: fatFilter)
                && matchesNumeric(food.fiber, filter: fiberFilter)
                && matchesNumeric(food.ash, filter: ashFilter)
                && matchesNumeric(food.moisture, filter: moistureFilter)

            return matchesText && matchesIngredients && matchesNewFilters
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

    /// 外部画面からドッグフード詳細を開きたいときに呼ぶ
    func openDogFoodDetail(_ dogFood: DogFood) {
        selectedDogFood = dogFood
    }
    
    // MARK: - Favorites タブ用
    var favoriteDogFoods: [DogFood] {
        dogFoods
            .filter { favoriteDogFoodIDs.contains($0.id ?? "") }
            .sorted { a, b in
                let dateA = favoriteCreatedAts[a.id ?? ""] ?? .distantPast
                let dateB = favoriteCreatedAts[b.id ?? ""] ?? .distantPast
                return dateA > dateB  // 新しく追加した順（降順）
            }
    }
    
}
