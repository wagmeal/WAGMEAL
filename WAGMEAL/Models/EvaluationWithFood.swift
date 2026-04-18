import Foundation

/// Firestoreの Evaluation と DogFood を結合した表示用モデル
/// - Identifiable: List/Grid で安定IDを利用
/// - Equatable: 差分更新などで利用
struct EvaluationWithFood: Identifiable, Equatable {
    let id: String
    let evaluation: Evaluation
    let dogFood: DogFood

    init(evaluation: Evaluation, dogFood: DogFood) {
        self.evaluation = evaluation
        self.dogFood = dogFood
        // evaluation.id が無い場合の安定ID（dogFoodId + UNIX秒）
        if let evalID = evaluation.id, !evalID.isEmpty {
            self.id = evalID
        } else {
            let ts = Int(evaluation.timestamp.timeIntervalSince1970)
            self.id = "\(evaluation.dogFoodId)_\(ts)"
        }
    }

    static func == (lhs: EvaluationWithFood, rhs: EvaluationWithFood) -> Bool {
        lhs.id == rhs.id
    }
}
