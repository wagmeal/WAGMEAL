//
//  RankingViewModel.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/08/05.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

// ランキング表示用のデータ構造
struct DogFoodRanking: Identifiable {
    let id: String  // dogFoodID
    let dogFood: DogFood
    let averageRating: Double
}

class RankingViewModel: ObservableObject {
    @Published var rankedDogFoods: [DogFoodRanking] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let useMockData: Bool
    private var selectedSizeCategory: String?
    
    func refresh(sizeCategory: String?) {
        self.selectedSizeCategory = sizeCategory
        if useMockData {
            loadMockData()
        } else {
            fetchRanking()
        }
    }
    
    init(useMockData: Bool = false, selectedSizeCategory: String? = nil) {
        self.useMockData = useMockData
        self.selectedSizeCategory = selectedSizeCategory

        if useMockData {
            loadMockData()
        } else {
            fetchRanking()
        }
    }

    private func fetchRanking() {
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
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            let grouped = Dictionary(grouping: documents) { $0["dogFoodId"] as? String ?? "" }
            var result: [DogFoodRanking] = []
            let group = DispatchGroup()

            for (dogFoodId, docs) in grouped {
                guard !dogFoodId.isEmpty else { continue }

                let ratings = docs.compactMap { $0["overall"] as? Int }
                guard !ratings.isEmpty else { continue }

                let average = Double(ratings.reduce(0, +)) / Double(ratings.count)

                group.enter()
                self.db.collection("dogfood").document(dogFoodId).getDocument { snapshot, error in
                    defer { group.leave() }

                    if let snapshot = snapshot, snapshot.exists {
                        do {
                            let dogFood = try snapshot.data(as: DogFood.self)
                            result.append(DogFoodRanking(id: dogFoodId, dogFood: dogFood, averageRating: average))
                            print("✅ dogFood loaded: \(dogFood.name)")
                        } catch {
                            print("❌ dogFood decode error: \(error)")
                        }
                    } else {
                        print("⚠️ no dogFood found for ID: \(dogFoodId)")
                    }
                }
            }

            group.notify(queue: .main) {
                print("🎉 all dogFood loaded")
                self.rankedDogFoods = result.sorted(by: { $0.averageRating > $1.averageRating })
                self.isLoading = false
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
            let average = Double(evals.map { $0.overall }.reduce(0, +)) / Double(evals.count)

            if let dogFood = dogFoods.first(where: { $0.id == dogFoodId }) {
                mockRankings.append(DogFoodRanking(id: dogFoodId, dogFood: dogFood, averageRating: average))
            }
        }

        self.rankedDogFoods = mockRankings.sorted(by: { $0.averageRating > $1.averageRating })
    }
    
    
}
