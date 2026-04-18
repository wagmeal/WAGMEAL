//
//  EvaluationInputView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/11.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseAnalytics

struct EvaluationInputView: View {
    let dogFoodID: String
    let dogs: [DogProfile]
    @Binding var selectedDogID: String?

    @Environment(\.dismiss) var dismiss

    // 評価項目：1〜5
    @State private var eatingRating: Int = 3            // 食いつき
    @State private var conditionRating: Int = 3         // 体調
    @State private var costPerformanceRating: Int = 3   // コスパ
    @State private var storageEaseRating: Int = 3       // 保存のしやすさ
    @State private var repurchaseRating: Int = 3        // また買いたい
    @State private var comment: String = ""
    @State private var feedingStartDate: Date = Date()
    @FocusState private var isCommentFocused: Bool
    @State private var hasFeedingStartDate: Bool = true
    @State private var hasFeedingEndDate: Bool = false
    @State private var feedingEndDate: Date? = nil
    @State private var isReviewPublic: Bool = true

    // 複数選択用
    @State private var selectedDogIDs: Set<String> = []

    private var selectedDogs: [DogProfile] {
        dogs.filter { dog in
            guard let id = dog.id else { return false }
            return selectedDogIDs.contains(id)
        }
    }

    var body: some View {
        Form {
            // ワンちゃん選択（複数選択）
            Section(header: Text("記録をつけるわんちゃん")) {
                if dogs.isEmpty {
                    Text("登録済みのわんちゃんがいません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dogs) { dog in
                        if let id = dog.id {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dog.name)
                                        .font(.body)
                                    Text("\(dog.breed) ・ \(ageString(for: dog))")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { selectedDogIDs.contains(id) },
                                    set: { isOn in
                                        if isOn {
                                            selectedDogIDs.insert(id)
                                        } else {
                                            selectedDogIDs.remove(id)
                                        }
                                        // 既存の単一選択Bindingは、1匹だけ選択されている時のみ同期
                                        selectedDogID = (selectedDogIDs.count == 1) ? selectedDogIDs.first : nil
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color(red: 184/255, green: 164/255, blue: 144/255))
                                .scaleEffect(0.9, anchor: .center)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            // 評価項目（星）
            Section(header: Text("各項目を評価（あとから修正可能）")) {

                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: $eatingRating, label: "食いつき", preset: .large)
                        .padding(.vertical, 4)
                    Text("食べるスピード・残しやすさ")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: $conditionRating, label: "体調", preset: .large)
                        .padding(.vertical, 4)
                    Text("便・皮膚・涙やけ・元気さなど")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: $costPerformanceRating, label: "コスパ", preset: .large)
                        .padding(.vertical, 4)
                    Text("価格に対する満足度")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: $storageEaseRating, label: "保存のしやすさ", preset: .large)
                        .padding(.vertical, 4)
                    Text("袋・保管のしやすさなど")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    StarRatingView(rating: $repurchaseRating, label: "また買いたい", preset: .large)
                        .padding(.vertical, 4)
                    Text("総合的に見てまた買いたいか")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            

            // 食べた期間（開始日＋終了日）
            Section(
                header: Text("食べた期間")
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    // 食べ始めた日：ラベル＋記録有無のトグル
                    HStack {
                        Text("食べ始めた日")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(hasFeedingStartDate ? "記録する" : "記録しない")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Toggle("", isOn: $hasFeedingStartDate)
                                .labelsHidden()
                                .tint(Color(red: 184/255, green: 164/255, blue: 144/255))
                                .scaleEffect(0.8, anchor: .center)
                        }
                    }

                    // 食べ始めた日ピッカー（記録する場合のみ表示）
                    if hasFeedingStartDate {
                        HStack {
                            Spacer()
                            DatePicker(
                                "",
                                selection: $feedingStartDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                        }
                    }

                    // 食べ終えた日：ラベル＋記録有無のトグル
                    HStack {
                        Text("食べ終えた日")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(hasFeedingEndDate ? "記録する" : "記録しない")
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Toggle("", isOn: $hasFeedingEndDate)
                                .labelsHidden()
                                .tint(Color(red: 184/255, green: 164/255, blue: 144/255))
                                .scaleEffect(0.8, anchor: .center)
                        }
                    }
                    
                    // 食べ終えた日ピッカー（記録する場合のみ表示）
                    if hasFeedingEndDate {
                        HStack {
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { feedingEndDate ?? feedingStartDate },
                                    set: { feedingEndDate = $0 }
                                ),
                                in: feedingStartDate...,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                        }
                    }
                    Text("日付はMyDogの「記録を確認」から追記可能です")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            // コメント ＋ 公開設定
            Section(header: Text("コメント")) {
                VStack(alignment: .leading, spacing: 8) {
                    // レビュー本文
                    TextEditor(text: $comment)
                        .focused($isCommentFocused)
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3))
                        )

                    // 公開設定（レビューセクション内に配置）
                    HStack {
                        Spacer()
                        Text(isReviewPublic ? "コメントを公開する" : "コメントを公開しない")
                            .font(.footnote)                  // 小さめフォント
                            .foregroundColor(.gray)           // 文字をグレーに
                        Toggle("", isOn: $isReviewPublic)
                            .labelsHidden()
                            .tint(Color(red: 184/255, green: 164/255, blue: 144/255))
                            .scaleEffect(0.8, anchor: .center) // トグルを少し小さく
                    }
                }
                .padding(.top, 8)
            }
            

            // 送信ボタン
            Button("登録") {
                submitEvaluation()
            }
            .disabled(selectedDogIDs.isEmpty)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedDogIDs.isEmpty ? Color.gray : Color(red: 184/255, green: 164/255, blue: 144/255))
            .cornerRadius(10)
        }
        .navigationTitle("記録の登録")
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "evaluation_input",
                AnalyticsParameterScreenClass: "EvaluationInputView"
            ])
            // 既存の単一選択値がある場合は初期選択として反映
            if let id = selectedDogID {
                selectedDogIDs = [id]
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isCommentFocused {
                    Button("完了") {
                        isCommentFocused = false
                    }
                }
                Button("キャンセル") {
                    Analytics.logEvent("evaluation_cancel", parameters: [
                        "food_id": dogFoodID,
                        "has_dog_selected": selectedDogID != nil
                    ])
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    isCommentFocused = false   // キーボードを閉じる
                }
            }
        }
    }

    // 年齢表示用（◯歳◯ヶ月）
    private func ageString(for dog: DogProfile, referenceDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: dog.birthDate, to: referenceDate)

        let years = components.year ?? 0
        let months = components.month ?? 0

        switch (years, months) {
        case (0, let m):
            return "\(m)ヶ月"
        case (let y, 0):
            return "\(y)歳"
        default:
            return "\(years)歳\(months)ヶ月"
        }
    }

    // Firestoreへ評価を保存（選択した全てのわんちゃんに同じ評価を登録）
    private func submitEvaluation() {
        guard !selectedDogIDs.isEmpty else {
            print("❌ ワンちゃんが選択されていません")
            return
        }

        // Analytics: submit attempt (do not send free text comment)
        Analytics.logEvent("evaluation_submit_attempt", parameters: [
            "food_id": dogFoodID,
            "dog_count": selectedDogIDs.count,
            "eating": eatingRating,
            "condition": conditionRating,
            "cost_performance": costPerformanceRating,
            "storage_ease": storageEaseRating,
            "repurchase": repurchaseRating,
            "comment_filled": !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "has_feeding_start": hasFeedingStartDate,
            "has_feeding_end": hasFeedingEndDate,
            "is_review_public": isReviewPublic
        ])

        let db = Firestore.firestore()
        let userID = Auth.auth().currentUser?.uid ?? "unknown"

        // 参照日（開始日があれば開始日、なければ終了日、どちらもなければ現在）
        let referenceDate: Date
        if hasFeedingStartDate {
            referenceDate = feedingStartDate
        } else if let end = feedingEndDate {
            referenceDate = end
        } else {
            referenceDate = Date()
        }

        // 複数保存の完了管理
        var remaining = selectedDogIDs.count
        var hadError = false

        for dogID in selectedDogIDs {
            guard let dog = dogs.first(where: { $0.id == dogID }) else {
                print("❌ 選択されたワンちゃんが無効です: \(dogID)")
                remaining -= 1
                continue
            }

            let dogAgeTextAtEvaluation = ageString(for: dog, referenceDate: referenceDate)

            var evaluationData: [String: Any] = [
                "dogID": dog.id ?? "",
                "dogName": dog.name,
                "breed": dog.breed,
                "sizeCategory": dog.sizeCategory,
                "dogAgeTextAtEvaluation": dogAgeTextAtEvaluation,
                "dogFoodId": dogFoodID,
                "userId": userID,
                "timestamp": Timestamp(),
                "eating": eatingRating,
                "condition": conditionRating,
                "costPerformance": costPerformanceRating,
                "storageEase": storageEaseRating,
                "repurchase": repurchaseRating,
                "comment": comment,
                "isReviewPublic": isReviewPublic,
                "ratings": [
                    "eating": eatingRating,
                    "condition": conditionRating,
                    "costPerformance": costPerformanceRating,
                    "storageEase": storageEaseRating,
                    "repurchase": repurchaseRating
                ]
            ]

            // 食べ始めた日
            if hasFeedingStartDate {
                evaluationData["feedingStartDate"] = Timestamp(date: feedingStartDate)
            } else {
                evaluationData["feedingStartDate"] = NSNull()
            }

            // 食べ終えた日
            if hasFeedingEndDate, let end = feedingEndDate {
                evaluationData["feedingEndDate"] = Timestamp(date: end)
            } else {
                evaluationData["feedingEndDate"] = NSNull()
            }

            db.collection("evaluations").addDocument(data: evaluationData) { error in
                if let error = error {
                    hadError = true
                    print("❌ 評価の保存に失敗(\(dogID)): \(error.localizedDescription)")
                } else {
                    print("✅ 評価を保存しました (\(dogID))")
                    Analytics.logEvent("evaluation_submit", parameters: [
                        "food_id": dogFoodID,
                        "dog_id": dogID,
                        "size_category": dog.sizeCategory,
                        "eating": eatingRating,
                        "condition": conditionRating,
                        "cost_performance": costPerformanceRating,
                        "storage_ease": storageEaseRating,
                        "repurchase": repurchaseRating,
                        "comment_filled": !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "has_feeding_start": hasFeedingStartDate,
                        "has_feeding_end": hasFeedingEndDate,
                        "is_review_public": isReviewPublic
                    ])
                }

                remaining -= 1
                if remaining <= 0 {
                    if hadError {
                        // 一部失敗しても画面は閉じる（要件に応じて変更可）
                        print("⚠️ 一部の評価保存に失敗しました")
                    }
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    struct EvaluationInputPreviewWrapper: View {
        @State private var selectedDogID: String? = "dog_001"

        var body: some View {
            let mockDogs = [
                DogProfile(
                    id: "dog_001",
                    name: "ココ",
                    birthDate: Date(),
                    gender: "メス",
                    breed: "マルプー",
                    sizeCategory:"大型犬",
                    createdAt: Date()
                ),
                DogProfile(
                    id: "dog_002",
                    name: "モモ",
                    birthDate: Date(),
                    gender: "オス",
                    breed: "チワワ",
                    sizeCategory:"大型犬",
                    createdAt: Date()
                )
            ]

            return NavigationStack {
                EvaluationInputView(
                    dogFoodID: "sample-dogfood-id",
                    dogs: mockDogs,
                    selectedDogID: $selectedDogID
                )
            }
        }
    }

    return EvaluationInputPreviewWrapper()
}
