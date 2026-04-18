//
//  Evaluation.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/21.
//

import Foundation
import FirebaseFirestore

struct Evaluation: Codable, Identifiable {
    @DocumentID var id: String?
    var dogID: String
    var dogName: String       // ← 追加
    var breed: String         // ← 追加
    var sizeCategory: String  // ← 追加（小型犬 / 中型犬 / 大型犬）
    var dogAgeTextAtEvaluation: String? = nil
    var dogFoodId: String
    var userId: String
    // ✅ 5項目の星評価（1〜5）
    var eating: Int              // 食いつき（食べるスピード・残しやすさ）
    var condition: Int           // 体調（便・皮膚・涙やけ・元気さなど）
    var costPerformance: Int     // コスパ（価格に対する満足度）
    var storageEase: Int         // 保存のしやすさ（袋、保管方法など）
    var repurchase: Int          // また買いたい（総合的に見てまた買いたいか）
    var comment: String?      // ← 任意項目として追加
    var isReviewPublic: Bool? = true
    var timestamp: Date = Date()
    var feedingStartDate: Date?
    var feedingEndDate: Date?
    var ratings: [String: Int]
    var barColorKey: String? = nil
    
    // ✅ 追加: Firestore→モデル変換のための便利メソッド
    static func fromFirestore(doc: QueryDocumentSnapshot) -> Evaluation? {
        let data = doc.data()
        let ratings = data["ratings"] as? [String: Int] ?? [:]

        let eating = data["eating"] as? Int ?? ratings["eating"] ?? 0
        let condition = data["condition"] as? Int ?? ratings["condition"] ?? 0
        let costPerformance = data["costPerformance"] as? Int ?? ratings["costPerformance"] ?? 0
        let storageEase = data["storageEase"] as? Int ?? ratings["storageEase"] ?? 0
        let repurchase = data["repurchase"] as? Int ?? ratings["repurchase"] ?? 0

        return Evaluation(
            id: doc.documentID,
            dogID: data["dogID"] as? String ?? "",
            dogName: data["dogName"] as? String ?? "",
            breed: data["breed"] as? String ?? "",
            sizeCategory: data["sizeCategory"] as? String ?? "",
            dogAgeTextAtEvaluation: data["dogAgeTextAtEvaluation"] as? String,
            dogFoodId: data["dogFoodId"] as? String ?? "",
            userId: data["userId"] as? String ?? "",
            eating: eating,
            condition: condition,
            costPerformance: costPerformance,
            storageEase: storageEase,
            repurchase: repurchase,
            comment: data["comment"] as? String ?? "",
            isReviewPublic: data["isReviewPublic"] as? Bool ?? true,
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            feedingStartDate: (data["feedingStartDate"] as? Timestamp)?.dateValue(),
            feedingEndDate: (data["feedingEndDate"] as? Timestamp)?.dateValue(),
            ratings: ratings,
            barColorKey: data["barColorKey"] as? String
        )
    }
    
    // ✅ 追加: 表示用に簡単な日付フォーマッタ
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: timestamp)
    }
}

// Evaluation.swift の末尾などに
extension Evaluation {
    // PreviewMockData.MockEvaluation の実フィールド名に合わせて調整してください
    init(fromMock m: PreviewMockData.MockEvaluation) {
        self.id = nil                  // なければ nil
        self.dogID = m.dogID
        self.dogName = m.dogName
        self.breed = m.breed
        self.sizeCategory = m.sizeCategory
        self.dogAgeTextAtEvaluation = nil
        self.dogFoodId = m.dogFoodId
        self.userId = m.userId
        self.eating = m.ratings["eating"] ?? 0
        self.condition = m.ratings["condition"] ?? 0
        self.costPerformance = m.ratings["costPerformance"] ?? 0
        self.storageEase = m.ratings["storageEase"] ?? 0
        self.repurchase = m.ratings["repurchase"] ?? 0
        self.comment = m.comment        // m.memo などなら合わせて変更
        self.isReviewPublic = m.isReviewPublic
        self.timestamp = m.timestamp
        self.feedingStartDate = m.feedingStartDate
        self.feedingEndDate = m.feedingEndDate
        self.ratings = m.ratings
        self.barColorKey = nil  // または m.barColorKey があればそれを設定
    }
}
