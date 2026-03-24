import FirebaseFirestore
import FirebaseFirestoreSwift   // ← Firestoreデコードを使うので追加

struct EvaluationAverage {
    var overall: Double
    var dogSatisfaction: Double
    var ownerSatisfaction: Double
}

class EvaluationViewModel: ObservableObject {
    // 平均値
    @Published var average: EvaluationAverage?

    // トップレビュー & 総件数
    @Published var topReviews: [Evaluation] = []
    @Published var totalReviewCount: Int = 0

    private var topListener: ListenerRegistration?
    private let isMock: Bool

    init(useMockData: Bool = false) {
        self.isMock = useMockData
    }

    deinit {
        topListener?.remove()
    }

    // MARK: - 平均値（foodIdごと）
    func fetchAverages(for dogFoodId: String) {
        if isMock {
            // —— モック —— foodIdでフィルタして平均
            let ms = PreviewMockData.evaluations.filter { $0.dogFoodId == dogFoodId }
            guard !ms.isEmpty else {
                DispatchQueue.main.async { self.average = nil }
                return
            }
            let c = Double(ms.count)
            let avg = EvaluationAverage(
                overall: ms.map { Double($0.overall) }.reduce(0,+) / c,
                dogSatisfaction: ms.map { Double($0.dogSatisfaction) }.reduce(0,+) / c,
                ownerSatisfaction: ms.map { Double($0.ownerSatisfaction) }.reduce(0,+) / c
            )
            DispatchQueue.main.async { self.average = avg }
            return
        }

        // —— Firestore —— foodIdで取得して平均
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
                    DispatchQueue.main.async { self.average = nil }
                    return
                }

                let c = Double(evaluations.count)
                let avg = EvaluationAverage(
                    overall: evaluations.map { Double($0.overall) }.reduce(0,+) / c,
                    dogSatisfaction: evaluations.map { Double($0.dogSatisfaction) }.reduce(0,+) / c,
                    ownerSatisfaction: evaluations.map { Double($0.ownerSatisfaction) }.reduce(0,+) / c
                )
                DispatchQueue.main.async { self.average = avg }
            }
    }

    // MARK: - トップ3レビュー（timestamp降順）
    func listenTopReviews(for dogFoodID: String, limit: Int = 3) {
        if isMock {
            // —— モック —— timestamp降順 → 上位limit件
            let ms = PreviewMockData.evaluations
                .filter { $0.dogFoodId == dogFoodID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
            // Evaluation の memberwise init を使って組み立て
            let items: [Evaluation] = ms.map { m in
                Evaluation(
                    id: nil,
                    dogID: m.dogID,
                    dogName: m.dogName,
                    breed: m.breed,
                    dogFoodId: m.dogFoodId,
                    userId: m.userId,
                    overall: m.overall,
                    dogSatisfaction: m.dogSatisfaction,
                    ownerSatisfaction: m.ownerSatisfaction,
                    comment: m.comment,
                    timestamp: m.timestamp,
                    ratings: m.ratings
                )
            }
            DispatchQueue.main.async { self.topReviews = items }
            return
        }

        // —— Firestore —— timestamp で並べる（createdAt ではない）
        topListener?.remove()
        let db = Firestore.firestore()
        let q = db.collection("evaluations")
            .whereField("dogFoodId", isEqualTo: dogFoodID)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)

        topListener = q.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            let items: [Evaluation] = snap?.documents.compactMap { doc in
                try? doc.data(as: Evaluation.self)
            } ?? []
            DispatchQueue.main.async { self.topReviews = items }
        }
    }

    // MARK: - 総件数
    func fetchReviewCount(for dogFoodID: String) {
        if isMock {
            // —— モック —— 件数だけ
            let count = PreviewMockData.evaluations.filter { $0.dogFoodId == dogFoodID }.count
            DispatchQueue.main.async { self.totalReviewCount = count }
            return
        }

        // —— Firestore —— Aggregation API（使えなければフォールバック）
        let db = Firestore.firestore()
        let q = db.collection("evaluations").whereField("dogFoodId", isEqualTo: dogFoodID)
        q.count.getAggregation(source: .server) { [weak self] agg, err in
            if let c = agg?.count.intValue {
                DispatchQueue.main.async { self?.totalReviewCount = c }
            } else {
                // フォールバック：getDocumentsで数える
                q.getDocuments { snap, _ in
                    let c = snap?.documents.count ?? 0
                    DispatchQueue.main.async { self?.totalReviewCount = c }
                }
            }
        }
    }
}

class MockEvaluationViewModel: EvaluationViewModel {
    static let shared = MockEvaluationViewModel()
    private init() { super.init(useMockData: true) }
}
