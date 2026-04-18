#if canImport(FirebaseFirestore)
import FirebaseFirestore // Firestoreデコード
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct EvaluationAverage {
    var eating: Double
    var condition: Double
    var costPerformance: Double
    var storageEase: Double
    var repurchase: Double
}

class EvaluationViewModel: ObservableObject {
    // MARK: - Preview判定（Xcode PreviewsではNetwork/Listenerを触らない）
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // 平均値
    @Published var average: EvaluationAverage?

    // トップレビュー & 総件数
    @Published var topReviews: [Evaluation] = []
    @Published var totalReviewCount: Int = 0

    // MARK: - 現在のごはん（dogIDごと）
    /// dogID -> 現在あげている dogFoodId の配列（表示順は新しい順、foodId重複なし）
    @Published var currentFeedingFoodIDsByDog: [String: [String]] = [:]

    /// dogID -> (dogFoodId -> 最新のEvaluation)
    /// 「いまのごはん」行タップで EvaluationDetailView に飛ぶために必要
    @Published var currentFeedingLatestEvaluationByDogAndFood: [String: [String: Evaluation]] = [:]

    #if canImport(FirebaseFirestore)
    private var topListener: ListenerRegistration?
    private var currentFeedingListener: ListenerRegistration?
    #else
    private var topListener: Any?
    private var currentFeedingListener: Any?
    #endif

    private let isMock: Bool

    init(useMockData: Bool = false) {
        // ✅ Previewsは強制的にモック（Network/Firestoreを触らない）
        if Self.isPreview {
            self.isMock = true
        } else {
            self.isMock = useMockData
        }
    }

    deinit {
        #if canImport(FirebaseFirestore)
        topListener?.remove()
        currentFeedingListener?.remove()
        #endif
    }

    // MARK: - 平均値（foodIdごと）
    func fetchAverages(for dogFoodId: String) {
        if isMock {
            let ms = PreviewMockData.evaluations.filter { $0.dogFoodId == dogFoodId }
            guard !ms.isEmpty else {
                self.average = nil
                return
            }
            let c = Double(ms.count)
            let avg = EvaluationAverage(
                eating: ms.map { Double($0.ratings["eating"] ?? 0) }.reduce(0,+) / c,
                condition: ms.map { Double($0.ratings["condition"] ?? 0) }.reduce(0,+) / c,
                costPerformance: ms.map { Double($0.ratings["costPerformance"] ?? 0) }.reduce(0,+) / c,
                storageEase: ms.map { Double($0.ratings["storageEase"] ?? 0) }.reduce(0,+) / c,
                repurchase: ms.map { Double($0.ratings["repurchase"] ?? 0) }.reduce(0,+) / c
            )
            self.average = avg
            return
        }

        #if !canImport(FirebaseFirestore)
        return
        #endif
        if Self.isPreview { return }

        let db = Firestore.firestore()
        db.collection("evaluations")
            .whereField("dogFoodId", isEqualTo: dogFoodId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching evaluations:", error.localizedDescription)
                    return
                }
                let evaluations: [Evaluation] = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Evaluation.self)
                } ?? []

                guard !evaluations.isEmpty else {
                    Task { @MainActor in self.average = nil }
                    return
                }

                let c = Double(evaluations.count)
                let avg = EvaluationAverage(
                    eating: evaluations.map { Double($0.eating) }.reduce(0,+) / c,
                    condition: evaluations.map { Double($0.condition) }.reduce(0,+) / c,
                    costPerformance: evaluations.map { Double($0.costPerformance) }.reduce(0,+) / c,
                    storageEase: evaluations.map { Double($0.storageEase) }.reduce(0,+) / c,
                    repurchase: evaluations.map { Double($0.repurchase) }.reduce(0,+) / c
                )
                Task { @MainActor in self.average = avg }
            }
    }

    // MARK: - トップ3レビュー（timestamp降順）
    func listenTopReviews(for dogFoodID: String, limit: Int = 3) {
        if isMock {
            let ms = PreviewMockData.evaluations
                .filter { $0.dogFoodId == dogFoodID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)

            let items: [Evaluation] = ms.map { m in
                Evaluation(
                    id: nil,
                    dogID: m.dogID,
                    dogName: m.dogName,
                    breed: m.breed,
                    sizeCategory: m.sizeCategory,
                    dogFoodId: m.dogFoodId,
                    userId: m.userId,
                    eating: m.ratings["eating"] ?? 0,
                    condition: m.ratings["condition"] ?? 0,
                    costPerformance: m.ratings["costPerformance"] ?? 0,
                    storageEase: m.ratings["storageEase"] ?? 0,
                    repurchase: m.ratings["repurchase"] ?? 0,
                    comment: m.comment,
                    timestamp: m.timestamp,
                    ratings: m.ratings
                )
            }
            self.topReviews = items
            return
        }

        #if !canImport(FirebaseFirestore)
        return
        #endif
        if Self.isPreview { return }

        topListener?.remove()
        let db = Firestore.firestore()
        let q = db.collection("evaluations")
            .whereField("dogFoodId", isEqualTo: dogFoodID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        topListener = q.addSnapshotListener { [weak self] snap, _ in
            guard let self = self else { return }
            let items: [Evaluation] = snap?.documents.compactMap { doc in
                try? doc.data(as: Evaluation.self)
            } ?? []
            Task { @MainActor in self.topReviews = items }
        }
    }

    // MARK: - 総件数
    func fetchReviewCount(for dogFoodID: String) {
        if isMock {
            let count = PreviewMockData.evaluations.filter { $0.dogFoodId == dogFoodID }.count
            self.totalReviewCount = count
            return
        }

        #if !canImport(FirebaseFirestore)
        return
        #endif
        if Self.isPreview { return }

        let db = Firestore.firestore()
        let q = db.collection("evaluations").whereField("dogFoodId", isEqualTo: dogFoodID)
        q.count.getAggregation(source: .server) { [weak self] agg, _ in
            if let c = agg?.count.intValue {
                Task { @MainActor [weak self] in self?.totalReviewCount = c }
            } else {
                q.getDocuments { [weak self] snap, _ in
                    let c = snap?.documents.count ?? 0
                    Task { @MainActor [weak self] in self?.totalReviewCount = c }
                }
            }
        }
    }

    // MARK: - 現在のごはん（ログインユーザーの評価から集計）
    /// 定義：feedingStartDate はある / feedingEndDate はない
    func listenCurrentFeedingFoodsForLoggedInUser() {
        // —— モック —— PreviewMockData から集計
        if isMock {
            let ms = PreviewMockData.evaluations
                .filter { $0.feedingStartDate != nil && $0.feedingEndDate == nil }
                .sorted { $0.timestamp > $1.timestamp }

            // foodId一覧（重複なし/新しい順）
            var idDict: [String: [String]] = [:]
            // 最新Evaluation（foodId重複は最新1件）
            var evalDict: [String: [String: Evaluation]] = [:]

            for m in ms {
                let dogID = m.dogID
                let foodID = m.dogFoodId

                if idDict[dogID] == nil { idDict[dogID] = [] }
                if idDict[dogID]?.contains(foodID) == false {
                    idDict[dogID]?.append(foodID)
                }

                if evalDict[dogID] == nil { evalDict[dogID] = [:] }
                // msはtimestamp降順なので「最初に入ったもの＝最新」でOK
                if evalDict[dogID]?[foodID] == nil {
                    let e = Evaluation(
                        id: nil,
                        dogID: m.dogID,
                        dogName: m.dogName,
                        breed: m.breed,
                        sizeCategory: m.sizeCategory,
                        dogFoodId: m.dogFoodId,
                        userId: m.userId,
                        eating: m.ratings["eating"] ?? 0,
                        condition: m.ratings["condition"] ?? 0,
                        costPerformance: m.ratings["costPerformance"] ?? 0,
                        storageEase: m.ratings["storageEase"] ?? 0,
                        repurchase: m.ratings["repurchase"] ?? 0,
                        comment: m.comment,
                        timestamp: m.timestamp,
                        ratings: m.ratings
                    )
                    evalDict[dogID]?[foodID] = e
                }
            }

            self.currentFeedingFoodIDsByDog = idDict
            self.currentFeedingLatestEvaluationByDogAndFood = evalDict
            return
        }

        #if !canImport(FirebaseFirestore)
        return
        #endif
        if Self.isPreview { return }

        guard let uid = Auth.auth().currentUser?.uid else {
            self.currentFeedingFoodIDsByDog = [:]
            self.currentFeedingLatestEvaluationByDogAndFood = [:]
            return
        }

        // —— Firestore ——
        // feedingEndDate == null をサーバー側で絞り、startDate はクライアント側で最終判定
        currentFeedingListener?.remove()

        let db = Firestore.firestore()
        let q = db.collection("evaluations")
            .whereField("userId", isEqualTo: uid)
            .whereField("feedingEndDate", isEqualTo: NSNull())
            .order(by: "timestamp", descending: true)

        currentFeedingListener = q.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("❌ Error listening current feeding foods:", err.localizedDescription)
                return
            }

            let items: [Evaluation] = snap?.documents.compactMap { doc in
                try? doc.data(as: Evaluation.self)
            } ?? []

            let current = items
                .filter { $0.feedingStartDate != nil }
                .filter { $0.feedingEndDate == nil }

            var idDict: [String: [String]] = [:]
            var evalDict: [String: [String: Evaluation]] = [:]

            for e in current {
                let dogID = e.dogID
                let foodID = e.dogFoodId

                if idDict[dogID] == nil { idDict[dogID] = [] }
                if idDict[dogID]?.contains(foodID) == false {
                    idDict[dogID]?.append(foodID)
                }

                if evalDict[dogID] == nil { evalDict[dogID] = [:] }
                // current は timestamp 降順なので、最初に入ったものが最新
                if evalDict[dogID]?[foodID] == nil {
                    evalDict[dogID]?[foodID] = e
                }
            }

            Task { @MainActor in
                self.currentFeedingFoodIDsByDog = idDict
                self.currentFeedingLatestEvaluationByDogAndFood = evalDict
            }
        }
    }

    /// dogID を指定して「いまのごはん」の foodId 配列を取得
    func currentFeedingFoodIDs(for dogID: String?) -> [String] {
        guard let dogID else { return [] }
        return currentFeedingFoodIDsByDog[dogID] ?? []
    }

    /// dogID + dogFoodId から「いまのごはん」の最新Evaluationを取得（行タップで詳細へ使う）
    func currentFeedingLatestEvaluation(for dogID: String?, dogFoodId: String?) -> Evaluation? {
        guard let dogID, let dogFoodId else { return nil }
        return currentFeedingLatestEvaluationByDogAndFood[dogID]?[dogFoodId]
    }
}

class MockEvaluationViewModel: EvaluationViewModel {
    static let shared = MockEvaluationViewModel()
    private init() { super.init(useMockData: true) }
}
