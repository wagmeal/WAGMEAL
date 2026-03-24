//
//  EvaluationInputView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/11.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EvaluationInputView: View {
    let dogFoodID: String
    let dogs: [DogProfile]
    @Binding var selectedDogID: String?

    @Environment(\.dismiss) var dismiss

    // 評価項目：1〜5
    @State private var overallRating: Int = 3
    @State private var dogSatisfaction: Int = 3
    @State private var ownerSatisfaction: Int = 3
    @State private var comment: String = ""
    @State private var feedingStartDate: Date = Date()
    @State private var hasFeedingStartDate: Bool = true
    @State private var hasFeedingEndDate: Bool = false
    @State private var feedingEndDate: Date? = nil
    @State private var isReviewPublic: Bool = true

    private var selectedDog: DogProfile? {
        guard let id = selectedDogID else { return nil }
        return dogs.first(where: { $0.id == id })
    }

    var body: some View {
        Form {
            // ワンちゃん選択
            Section(header: Text("わんちゃんを選択")) {
                // 左寄せ＆下向き三角のメニュー形式
                Menu {
                    ForEach(dogs) { dog in
                        Button {
                            selectedDogID = dog.id
                        } label: {
                            Text(dog.name)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedDog?.name ?? "わんちゃんを選択")
                            .foregroundColor(.blue) // Pickerと同じリンク風の色
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                
                if let selectedDog {
                    Text("犬種: \(selectedDog.breed) 　　年齢: \(ageString(for: selectedDog))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            // 評価項目（星）
            Section(header: Text("各項目を評価（1〜5）")) {
                StarRatingView(rating: $overallRating, label: "総合評価")

                VStack(alignment: .leading, spacing: 2) {
                    StarRatingView(rating: $dogSatisfaction, label: "わんちゃんの満足度")
                    Text("添加物の有無、食いつきの良さ、便の状態 など")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    StarRatingView(rating: $ownerSatisfaction, label: "飼い主の満足度")
                    Text("コストパフォーマンス、保存のしやすさ など")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            // 食べた期間（開始日＋終了日）
            Section(
                header: Text("\(selectedDog?.name ?? "ワンちゃん") が食べた期間")
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
                    Text("日付はMyDogの「過去の記録を見る」から追記可能です")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            // コメント ＋ 公開設定
            Section(header: Text("コメント")) {
                VStack(alignment: .leading, spacing: 8) {
                    // レビュー本文
                    TextEditor(text: $comment)
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
            .disabled(selectedDogID == nil)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedDogID == nil ? Color.gray : Color(red: 184/255, green: 164/255, blue: 144/255))
            .cornerRadius(10)
        }
        .navigationTitle("記録の登録")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("キャンセル") {
                    dismiss()
                }
            }
        }
    }

    // 年齢表示用（◯歳◯ヶ月）
    private func ageString(for dog: DogProfile) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: dog.birthDate, to: now)

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

    // Firestoreへ評価を保存
    private func submitEvaluation() {
        guard
            let dogID = selectedDogID,
            let dog = dogs.first(where: { $0.id == dogID })
        else {
            print("❌ 選択されたワンちゃんが無効です")
            return
        }

        let db = Firestore.firestore()
        let userID = Auth.auth().currentUser?.uid ?? "unknown"

        var evaluationData: [String: Any] = [
            "dogID": dog.id ?? "",
            "dogName": dog.name,
            "breed": dog.breed,
            "sizeCategory": dog.sizeCategory,
            "dogFoodId": dogFoodID,
            "userId": userID,
            "timestamp": Timestamp(),
            "overall": overallRating,
            "dogSatisfaction": dogSatisfaction,
            "ownerSatisfaction": ownerSatisfaction,
            "comment": comment,
            "isReviewPublic": isReviewPublic,
            "ratings": [
                "総合評価": overallRating,
                "わんちゃんの満足度": dogSatisfaction,
                "飼い主の満足度": ownerSatisfaction
            ]
        ]

        if hasFeedingStartDate {
            evaluationData["feedingStartDate"] = Timestamp(date: feedingStartDate)
        }

        if hasFeedingEndDate, let end = feedingEndDate {
            evaluationData["feedingEndDate"] = Timestamp(date: end)
        }

        db.collection("evaluations").addDocument(data: evaluationData) { error in
            if let error = error {
                print("❌ 評価の保存に失敗: \(error.localizedDescription)")
            } else {
                print("✅ 評価を保存しました")
                dismiss()
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
