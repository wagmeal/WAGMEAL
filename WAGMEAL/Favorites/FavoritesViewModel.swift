import Foundation
import FirebaseAuth
import FirebaseFirestore

class FavoritesViewModel: ObservableObject {
    @Published var favoriteDogFoods: [DogFood] = []
    @Published var isLoading = true

    private let useMockData: Bool
    private let mockUserId: String?

    init(useMockData: Bool = false, mockUserId: String? = nil) {
        self.useMockData = useMockData
        self.mockUserId = mockUserId
    }

    func start() {
        isLoading = true
        if useMockData {
            loadMock()
        } else {
            fetchFavorites()
        }
    }

    private func loadMock() {
        let uid = mockUserId ?? "user_001"
        self.favoriteDogFoods = PreviewMockData.favoriteDogFoods(for: uid)
        self.isLoading = false
    }

    func fetchFavorites() {
        isLoading = true

        guard let userID = Auth.auth().currentUser?.uid else {
            print("❌ ユーザー未ログイン")
            self.isLoading = false
            self.favoriteDogFoods = []
            return
        }

        let db = Firestore.firestore()
        let favoritesRef = db.collection("users").document(userID).collection("favorites")

        favoritesRef.getDocuments(source: .default) { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("🔥 お気に入り取得失敗: \(error.localizedDescription)")
                self.isLoading = false
                self.favoriteDogFoods = []
                return
            }

            let dogFoodIDs = snapshot?.documents.map { $0.documentID } ?? []

            // 0件なら即終了
            if dogFoodIDs.isEmpty {
                self.favoriteDogFoods = []
                self.isLoading = false
                return
            }

            let group = DispatchGroup()
            // スレッドセーフにためる：ID -> DogFood
            var resultDict: [String: DogFood] = [:]
            let resultQueue = DispatchQueue(label: "favorites.result.queue")

            for id in dogFoodIDs {
                group.enter()
                db.collection("dogfood").document(id).getDocument(source: .default) { docSnapshot, _ in
                    defer { group.leave() }

                    guard
                        let doc = docSnapshot,
                        doc.exists,
                        let data = doc.data(),
                        let name = data["name"] as? String,
                        let description = data["description"] as? String,
                        let summary = data["summary"] as? String,
                        let keywords = data["keywords"] as? [String],
                        let imagePath = data["imagePath"] as? String
                    else {
                        print("⚠️ 不足フィールド or ドキュメントなし（ID: \(id)）")
                        return
                    }

                    // 欠損時のフォールバック（あれば）
                    let ingredients = (data["ingredients"] as? String) ?? ""
                    let brand = data["brand"] as? String

                    // 各種リンク（存在しない場合は nil）
                    let homepageURL = data["homepageURL"] as? String
                    let amazonURL = data["amazonURL"] as? String
                    let yahooURL = data["yahooURL"] as? String
                    let rakutenURL = data["rakutenURL"] as? String

                    let dogFood = DogFood(
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

                    // 辞書に安全に格納
                    resultQueue.sync {
                        resultDict[id] = dogFood
                    }
                }
            }

            group.notify(queue: .main) {
                // favorites の順序を維持して並べる
                let ordered = dogFoodIDs.compactMap { resultDict[$0] }
                self.favoriteDogFoods = ordered
                self.isLoading = false
            }
        }
    }
}
