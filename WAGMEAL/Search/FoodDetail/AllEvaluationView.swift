import SwiftUI
import FirebaseFirestore
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
import UIKit

#if DEBUG
private let IS_PREVIEW = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
private let IS_PREVIEW = false
#endif

// MARK: - Rating summary helper
private struct RatingStats {
    var counts: [Int] = [0, 0, 0, 0, 0]   // index 0 => ★5, 4 => ★1
    var total: Int = 0
    var average: Double = 0
    var percentages: [Double] {
        guard total > 0 else { return [0,0,0,0,0] }
        return counts.map { Double($0) / Double(total) }
    }
}

@MainActor
struct AllEvaluationsView: View {
    let dogFoodID: String
    let dogFood: DogFood?   // 画像・名前など表示用

    @State private var items: [Evaluation] = []
    @State private var isLoading = true

    // DogFoodDetailView と同じ方式：UIImage を状態で保持
    @State private var uiImage: UIImage?
    @State private var imageLoadError: String?
    @State private var isLoadingImage = false

    // 集計
    @State private var stats = RatingStats()

    // 並び替えキー（右側統計のラベルや reviews 並び替えに使用）
    enum SortKey: String, CaseIterable, Identifiable {
        case repurchase = "また買いたい順"
        case eating = "食いつき順"
        case condition = "体調順"
        case costPerformance = "コスパ順"
        case storageEase = "保存のしやすさ順"
        case date = "日付順"
        var id: String { rawValue }
    }
    @State private var sortKey: SortKey = .repurchase

    @Environment(\.dismiss) private var dismiss

    // MARK: - Inits
    init(dogFoodID: String, dogFood: DogFood? = nil) {
        self.dogFoodID = dogFoodID
        self.dogFood = dogFood
        self._items = State(initialValue: [])
        self._isLoading = State(initialValue: true)
    }

    // プレビュー／モック用（Firestore を叩かず items を注入）
    init(dogFoodID: String, dogFood: DogFood? = nil, mockItems: [Evaluation]) {
        self.dogFoodID = dogFoodID
        self.dogFood = dogFood
        self._items = State(initialValue: mockItems)
        self._isLoading = State(initialValue: false)
        var s = RatingStats()
        s.total = mockItems.count
        for e in mockItems { s = Self.add(e: e, into: s) }
        s.average = Self.computeAverage(from: mockItems)
        self._stats = State(initialValue: s)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                Spacer(minLength: 20)
                Text("レビューコメント")
                    .font(.title3)
                    .bold()

                // ヘッダー（固定）
                VStack(alignment: .leading, spacing: 16) {
                    headerSection()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    Divider()
                    
                    // レビュー一覧のみスクロール
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            reviewsSection()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                    }
                    .background(Color(.systemGray6))
                }
            }

            // 左上のバツボタン（閉じる）
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 16)
        }
        .onAppear {
            if isLoading { load() } else { updateStatsAndSort() }
            fetchHeaderImage()
        }
        .task(id: dogFood?.imagePath ?? "") {
            // 画像の状態リセット → 再取得（DogFoodDetailView と同様）
            uiImage = nil
            imageLoadError = nil
            isLoadingImage = false
            fetchHeaderImage()
        }
        .onChange(of: sortKey) { _ in
            updateStatsAndSort()
        }
        .onChange(of: itemsChangeToken) { _ in
            // Equatable 不要のトークン監視で統計を再計算
            recomputeStats()
        }
    }

    // Array<Evaluation> は Equatable ではないため、変更検知用トークンを作る
    private var itemsChangeToken: String {
        items.map { e in
            let id = e.id ?? ""
            let t = Optional(e.timestamp)?.timeIntervalSince1970 ?? 0
            return "\(id)|\(e.eating)|\(e.condition)|\(e.costPerformance)|\(e.storageEase)|\(e.repurchase)|\(t)"
        }
        .joined(separator: ",")
    }

    // MARK: - Header (商品画像 + 平均 + 統計 + 並び替え)
    @ViewBuilder private func headerSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 16) {
                // 左：画像 + 平均
                VStack(alignment: .leading, spacing: 5) {
                    ZStack {
                        if let img = uiImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if isLoadingImage {
                            Color.gray.opacity(0.1)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // 読み込み失敗時のフォールバック（DogFoodDetailView と同等）
                            Image("imagefail2")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.2f", stats.average))
                            .font(.system(size: 28, weight: .bold))
                        Text("(\(stats.total)件)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ReadOnlyStarRatingView(rating: stats.average, size: 16)
                }
                .frame(width: 140, alignment: .leading)

                // 右：評価の統計（★5→★1）＋ 並び替えメニュー
                VStack(alignment: .leading, spacing: 8) {
                    // 現在の統計の対象ラベル
                    Text(statsTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach((1...5).reversed(), id: \.self) { star in
                        let idx = 5 - star // 0..4
                        HStack(spacing: 8) {
                            Text("★\(star)")
                                .font(.subheadline)
                                .frame(width: 28, alignment: .leading)
                            ProgressView(value: stats.percentages[idx])
                                .progressViewStyle(.linear)
                            Text("\(Int(round(stats.percentages[idx] * 100)))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // 並び替えメニュー（右寄せ＆下三角ラベル）
                    Menu {
                        ForEach(SortKey.allCases) { key in
                            Button {
                                sortKey = key
                            } label: {
                                HStack {
                                    if sortKey == key { Image(systemName: "checkmark") }
                                    Text(key.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sortKey.rawValue)
                                .font(.subheadline)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.caption)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Reviews list
    @ViewBuilder private func reviewsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if items.isEmpty {
                Text("まだレビューがありません").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(items.indices, id: \.self) { idx in
                        let e = items[idx]
                        // 犬の年齢（dogAgeTextAtEvaluation）を渡す
                        let ageText = e.dogAgeTextAtEvaluation
                        ReviewCard(e: e, ageText: ageText)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    // MARK: - Load + helpers
    private func load() {
        let db = Firestore.firestore()
        db.collection("evaluations")
            .whereField("dogFoodId", isEqualTo: dogFoodID)
            .order(by: "timestamp", descending: true)
            .getDocuments { snap, _ in
                Task { @MainActor in
                    self.isLoading = false
                    guard let docs = snap?.documents else { return }
                    let loaded = docs.compactMap { try? $0.data(as: Evaluation.self) }
                    self.items = loaded
                    updateStatsAndSort()
                }
            }
    }

    private static func add(e: Evaluation, into stats: RatingStats) -> RatingStats {
        var s = stats
        var star = Int(round(Double(e.repurchase)))
        star = max(1, min(5, star))
        let idx = 5 - star
        s.counts[idx] += 1
        return s
    }

    private static func computeAverage(from items: [Evaluation]) -> Double {
        guard !items.isEmpty else { return 0 }
        let sum = items.reduce(0.0) { $0 + Double($1.repurchase) }
        return sum / Double(items.count)
    }

    // 現在の選択に応じて並び替えと統計を更新
    private func updateStatsAndSort() {
        applySort()
        recomputeStats()
    }

    // 並び替え
    private func applySort() {
        switch sortKey {
        case .repurchase:
            items.sort { lhs, rhs in
                if lhs.repurchase == rhs.repurchase {
                    return (Optional(lhs.timestamp) ?? .distantPast) > (Optional(rhs.timestamp) ?? .distantPast)
                }
                return lhs.repurchase > rhs.repurchase
            }
        case .eating:
            items.sort { lhs, rhs in
                if lhs.eating == rhs.eating {
                    return (Optional(lhs.timestamp) ?? .distantPast) > (Optional(rhs.timestamp) ?? .distantPast)
                }
                return lhs.eating > rhs.eating
            }
        case .condition:
            items.sort { lhs, rhs in
                if lhs.condition == rhs.condition {
                    return (Optional(lhs.timestamp) ?? .distantPast) > (Optional(rhs.timestamp) ?? .distantPast)
                }
                return lhs.condition > rhs.condition
            }
        case .costPerformance:
            items.sort { lhs, rhs in
                if lhs.costPerformance == rhs.costPerformance {
                    return (Optional(lhs.timestamp) ?? .distantPast) > (Optional(rhs.timestamp) ?? .distantPast)
                }
                return lhs.costPerformance > rhs.costPerformance
            }
        case .storageEase:
            items.sort { lhs, rhs in
                if lhs.storageEase == rhs.storageEase {
                    return (Optional(lhs.timestamp) ?? .distantPast) > (Optional(rhs.timestamp) ?? .distantPast)
                }
                return lhs.storageEase > rhs.storageEase
            }
        case .date:
            items.sort { a, b in
                (a.timestamp) > (b.timestamp)
            }
        }
    }

    // 表示すべき統計の対象メトリクス（仕様：日付順のときはまた買いたい）
    private var statsMetricKey: SortKey {
        switch sortKey {
        case .date:
            return .repurchase
        default:
            return sortKey
        }
    }

    // 現在の選択に応じた統計タイトル
    private var statsTitle: String {
        switch statsMetricKey {
        case .repurchase:      return "また買いたい"
        case .eating:          return "食いつき"
        case .condition:       return "体調"
        case .costPerformance: return "コスパ"
        case .storageEase:     return "保存のしやすさ"
        case .date:            return "また買いたい" // フォールバック
        }
    }

    // items から統計を再計算
    private func recomputeStats() {
        guard !items.isEmpty else {
            stats = RatingStats()
            return
        }
        var s = RatingStats()
        s.total = items.count

        var sum = 0.0
        for e in items {
            let v: Int
            switch statsMetricKey {
            case .repurchase:      v = e.repurchase
            case .eating:          v = e.eating
            case .condition:       v = e.condition
            case .costPerformance: v = e.costPerformance
            case .storageEase:     v = e.storageEase
            case .date:            v = e.repurchase
            }
            sum += Double(v)
            let clamped = max(1, min(5, Int(round(Double(v)))))
            let idx = 5 - clamped // ★5→index 0
            s.counts[idx] += 1
        }
        s.average = sum / Double(items.count)
        stats = s
    }

    // MARK: - Image fetch via SDK (getData) — DogFoodDetailView と同仕様
    private func fetchHeaderImage(maxSize: Int64 = 8 * 1024 * 1024) {
        guard !isLoadingImage else { return }
        imageLoadError = nil
        isLoadingImage = true

        guard let path = dogFood?.imagePath, !path.isEmpty else {
            isLoadingImage = false
            return
        }

        // http/https 直URLにも対応
        if path.lowercased().hasPrefix("http"), let url = URL(string: path) {
            URLSession.shared.dataTask(with: url) { data, _, error in
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    if let data, let img = UIImage(data: data) {
                        self.uiImage = img
                    } else if let error {
                        self.imageLoadError = "HTTP image load failed: \(error.localizedDescription)"
                    } else {
                        self.imageLoadError = "HTTP image load failed: Unknown"
                    }
                }
            }.resume()
            return
        }

        #if canImport(FirebaseStorage)
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            self.isLoadingImage = false
            self.imageLoadError = "FirebaseApp not configured"
            return
        }
        #endif

        let ref = Storage.storage().reference(withPath: path)
        ref.getData(maxSize: maxSize) { data, error in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                if let data, let img = UIImage(data: data) {
                    self.uiImage = img
                } else if let error = error as NSError? {
                    self.uiImage = nil
                    self.imageLoadError = "[\(error.domain) \(error.code)] \(error.localizedDescription)"
                    print("❌ Storage getData 失敗:", error)
                } else {
                    self.uiImage = nil
                    self.imageLoadError = "Unknown image load error"
                    print("❌ Storage getData 失敗: Unknown")
                }
            }
        }
        #else
        self.isLoadingImage = false
        self.imageLoadError = "Storage unavailable"
        #endif
    }

    private func fmtDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: d)
    }
}

// MARK: - Preview

#Preview("AllEvaluations – モック food_001") {
    #if canImport(FirebaseCore)
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    #endif
    let fid = "food_001"
    let food = PreviewMockData.dogFood.first { $0.id == fid }
    let mockItems: [Evaluation] = PreviewMockData.evaluations
        .filter { $0.dogFoodId == fid }
        .sorted { $0.timestamp > $1.timestamp }
        .map { m in
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
    return NavigationStack {
        AllEvaluationsView(dogFoodID: fid, dogFood: food, mockItems: mockItems)
    }
}

