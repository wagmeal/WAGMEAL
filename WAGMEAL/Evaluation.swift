//
//  Evaluation.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/21.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Evaluation: Codable, Identifiable {
    @DocumentID var id: String?
    var dogID: String
    var dogName: String       // ← 追加
    var breed: String         // ← 追加
    var dogFoodId: String
    var userId: String
    var overall: Int
    var dogSatisfaction: Int
    var ownerSatisfaction: Int
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
        return Evaluation(
            id: doc.documentID,
            dogID: data["dogID"] as? String ?? "",
            dogName: data["dogName"] as? String ?? "",
            breed: data["breed"] as? String ?? "",
            dogFoodId: data["dogFoodId"] as? String ?? "",
            userId: data["userId"] as? String ?? "",
            overall: data["overall"] as? Int ?? 0,
            dogSatisfaction: data["dogSatisfaction"] as? Int ?? 0,
            ownerSatisfaction: data["ownerSatisfaction"] as? Int ?? 0,
            comment: data["comment"] as? String ?? "",
            isReviewPublic: data["isReviewPublic"] as? Bool ?? true,
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            feedingStartDate: (data["feedingStartDate"] as? Timestamp)?.dateValue(),
            feedingEndDate: (data["feedingEndDate"] as? Timestamp)?.dateValue(),
            ratings: data["ratings"] as? [String: Int] ?? [:],
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
        self.dogFoodId = m.dogFoodId
        self.userId = m.userId
        self.overall = m.overall
        self.dogSatisfaction = m.dogSatisfaction
        self.ownerSatisfaction = m.ownerSatisfaction
        self.comment = m.comment        // m.memo などなら合わせて変更
        self.isReviewPublic = m.isReviewPublic
        self.timestamp = m.timestamp
        self.feedingStartDate = m.feedingStartDate
        self.feedingEndDate = m.feedingEndDate
        self.ratings = m.ratings
        self.barColorKey = nil  // または m.barColorKey があればそれを設定
    }
}
