//
//  RankingViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/08/05.
//

import Foundation
import FirebaseFirestore

// ランキング表示用のデータ構造
struct DogFoodRanking: Identifiable {
    let id: String  // dogFoodID
    let dogFood: DogFood
    let averageRating: Double
    let ratingCount: Int
}

class RankingViewModel: ObservableObject {
    @Published var rankedDogFoods: [DogFoodRanking] = []
    @Published var isLoading = false
    
    /// RankingView から参照しやすいように別名を用意（既存参照互換）
    typealias RankedDogFood = DogFoodRanking

    // MARK: - Preview判定（Xcode PreviewsではFirebaseを触らない）
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private lazy var db: Firestore? = {
        guard !Self.isPreview else { return nil }
        return Firestore.firestore()
    }()
    private let useMockData: Bool
    private var selectedSizeCategory: String?
    
    func refresh(sizeCategory: String?) {
        self.selectedSizeCategory = sizeCategory
        if Self.isPreview || useMockData {
            loadMockData()
        } else {
            fetchRanking()
        }
    }
    
    init(useMockData: Bool = false, selectedSizeCategory: String? = nil) {
        // Previewsでは必ずモック（Firestoreを触らない）
        if Self.isPreview {
            self.useMockData = true
            self.selectedSizeCategory = selectedSizeCategory
            loadMockData()
            return
        }

        self.useMockData = useMockData
        self.selectedSizeCategory = selectedSizeCategory

        if useMockData {
            loadMockData()
        } else {
            fetchRanking()
        }
    }

    private func fetchRanking() {
        guard !Self.isPreview else {
            loadMockData()
            return
        }
        guard let db = db else {
            loadMockData()
            return
        }

        print("📡 fetchRanking started")
        isLoading = true

        var query: Query = db.collection("evaluations")
        if let size = selectedSizeCategory {
            query = query.whereField("sizeCategory", isEqualTo: size)
        }

        query.getDocuments { snapshot, error in
            print("📄 evaluations fetched: \(snapshot?.documents.count ?? 0)")

            guard let documents = snapshot?.documents, error == nil else {
                print("❌ evaluations fetch error: \(String(describing: error))")
                Task { @MainActor [weak self] in self?.isLoading = false }
                return
            }

            let grouped = Dictionary(grouping: documents) { $0["dogFoodId"] as? String ?? "" }
            var result: [DogFoodRanking] = []
            let group = DispatchGroup()

            for (dogFoodId, docs) in grouped {
                guard !dogFoodId.isEmpty else { continue }

                // 5項目化後は「また買いたい」をランキングの代表指標として使用
                let ratings = docs.compactMap { $0["repurchase"] as? Int }
                guard !ratings.isEmpty else { continue }

                let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
                let count = ratings.count

                group.enter()
                db.collection("dogfood").document(dogFoodId).getDocument { snapshot, error in
                    defer { group.leave() }

                    if let snapshot = snapshot, snapshot.exists {
                        do {
                            let dogFood = try snapshot.data(as: DogFood.self)
                            result.append(DogFoodRanking(id: dogFoodId, dogFood: dogFood, averageRating: average, ratingCount: count))
                            print("✅ dogFood loaded: \(dogFood.name)")
                        } catch {
                            print("❌ dogFood decode error: \(error)")
                        }
                    } else {
                        print("⚠️ no dogFood found for ID: \(dogFoodId)")
                    }
                }
            }

            group.notify(queue: .global()) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.rankedDogFoods = self.sortedRankings(result)
                    self.isLoading = false
                    print("🎉 all dogFood loaded")
                }
            }
        }
    }

    private func loadMockData() {
        let evaluations: [PreviewMockData.MockEvaluation]
        if let size = selectedSizeCategory {
            evaluations = PreviewMockData.evaluations.filter { $0.sizeCategory == size }
        } else {
            evaluations = PreviewMockData.evaluations
        }

        let dogFoods = PreviewMockData.dogFood
        let grouped = Dictionary(grouping: evaluations, by: { $0.dogFoodId })

        var mockRankings: [DogFoodRanking] = []

        for (dogFoodId, evals) in grouped {
            // 5項目化後は「また買いたい」をランキングの代表指標として使用
            let average = Double(evals.map { $0.repurchase }.reduce(0, +)) / Double(evals.count)
            let count = evals.count

            if let dogFood = dogFoods.first(where: { $0.id == dogFoodId }) {
                mockRankings.append(DogFoodRanking(id: dogFoodId, dogFood: dogFood, averageRating: average, ratingCount: count))
            }
        }

        self.rankedDogFoods = sortedRankings(mockRankings)
    }

    // MARK: - Helpers
    private func sortedRankings(_ rankings: [DogFoodRanking]) -> [DogFoodRanking] {
        rankings.sorted { a, b in
            // 1) 平均評価（高い順）
            if a.averageRating != b.averageRating { return a.averageRating > b.averageRating }
            // 2) 評価件数（多い順）
            if a.ratingCount != b.ratingCount { return a.ratingCount > b.ratingCount }
            // 3) 名前（昇順）
            let nameOrder = a.dogFood.name.localizedCaseInsensitiveCompare(b.dogFood.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            // 4) IDで決定（昇順）
            return a.id.localizedCaseInsensitiveCompare(b.id) == .orderedAscending
        }
    }
    
    
}
