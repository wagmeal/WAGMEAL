import SwiftUI
import FirebaseFirestore

private enum FeedingBarColor: String, CaseIterable, Identifiable {
    case beige
    case blue
    case green
    case orange
    case purple
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .beige:  return "ベージュ"
        case .blue:   return "ブルー"
        case .green:  return "グリーン"
        case .orange: return "オレンジ"
        case .purple: return "パープル"
        }
    }
    
    var color: Color {
        switch self {
        case .beige:
            return Color(red: 184/255, green: 164/255, blue: 144/255)
        case .blue:
            return Color.blue
        case .green:
            return Color.green
        case .orange:
            return Color.orange
        case .purple:
            return Color.purple
        }
    }
}

/// 評価の詳細画面（DogFoodDetailViewと同等のUI構成）
/// - 表示項目: 写真 / ドッグフード名 / 評価日 / メモ / 3種評価
struct EvaluationDetailView: View {
    let item: EvaluationWithFood
    @Binding var isPresented: Bool
    @StateObject private var keyboard = KeyboardObserver()


    @State private var feedingStart: Date = Date()
    @State private var feedingEnd: Date?
    @State private var hasEndDate: Bool = false
    @State private var isSavingFeedingPeriod: Bool = false
    @State private var feedingPeriodError: String?
    @State private var selectedBarColor: FeedingBarColor = .beige

    @State private var editableComment: String = ""
    @State private var isReviewPublic: Bool = true
    
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false

    // MARK: - アレルギー情報（DogFoodDetailView と同等のラベル生成）
    private var allergyItems: [String] {
        var items: [String] = []
        let food = item.dogFood
        if food.hasChicken ?? false { items.append("鶏肉") }
        if food.hasBeef ?? false { items.append("牛肉") }
        if food.hasPork ?? false { items.append("豚肉") }
        if food.hasLamb ?? false { items.append("ラム／羊") }
        if food.hasFish ?? false { items.append("魚") }
        if food.hasEgg ?? false { items.append("卵") }
        if food.hasDairy ?? false { items.append("乳製品") }
        if food.hasWheat ?? false { items.append("小麦") }
        if food.hasCorn ?? false { items.append("トウモロコシ") }
        if food.hasSoy ?? false { items.append("大豆") }
        return items
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    infoSection()
                }
                .padding(.top, 16)
                .padding(.horizontal)
                .padding(.bottom, 100)
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .padding(.bottom, keyboard.height)

            Button {
                hideKeyboard()
                withAnimation(.spring()) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(10)
                    .shadow(radius: 1, y: 1)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            let ev = item.evaluation
            feedingStart = ev.feedingStartDate ?? ev.timestamp
            feedingEnd = ev.feedingEndDate
            hasEndDate = feedingEnd != nil

            // コメント＆公開設定の初期値
            editableComment = ev.comment ?? ""
            isReviewPublic = ev.isReviewPublic ?? true

            if let key = ev.barColorKey, let c = FeedingBarColor(rawValue: key) {
                selectedBarColor = c
            } else {
                selectedBarColor = .beige
            }
        }
        .onDisappear {
            // 画面を閉じる・スワイプで戻るときにキーボードを確実に閉じる
            hideKeyboard()
        }
        .toolbar {
            // キーボード上部に「完了」ボタンを表示
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    hideKeyboard()
                }
            }
        }
        // 🔽 ここを追加
        .alert("この記録を削除しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("削除する", role: .destructive) {
                deleteEvaluation()
            }
        } message: {
            Text("一度削除すると元に戻せません。")
        }
    }
    

    // MARK: - Small header image (AsyncImage, URL from imagePath)
    private func smallHeaderImage() -> some View {
        ZStack {
            if let url = URL(string: item.dogFood.imagePath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        if let local = UIImage(named: item.dogFood.imagePath) {
                            Image(uiImage: local)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image("imagefail2")
                                .resizable()
                                .scaledToFill()
                        }
                    @unknown default:
                        Image("imagefail2")
                            .resizable()
                            .scaledToFill()
                    }
                }
            } else {
                if let local = UIImage(named: item.dogFood.imagePath) {
                    Image(uiImage: local)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image("imagefail2")
                        .resizable()
                        .scaledToFill()
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
    }
    
    // MARK: - Info section（DogFoodDetailView の infoSection 構成に準拠）
    private func infoSection() -> some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                
                HStack(alignment: .center, spacing: 12) {
                    smallHeaderImage()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // タイトル
                        Text(item.dogFood.name)
                            .font(.title)
                            .bold()
                        
                        // 評価日
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                            Text(dateStringJP(item.evaluation.timestamp))
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                
                if !allergyItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        TagFlowLayout(spacing: 8) {
                            ForEach(allergyItems, id: \.self) { item in
                                AllergyTagView(text: item)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // みんなの評価表示の代わりに「今回の評価」を3行表示
                RatingRow(title: "総合評価",           value: Double(item.evaluation.overall),           starSize: 18)
                RatingRow(title: "わんちゃんの満足度", value: Double(item.evaluation.dogSatisfaction),   starSize: 18)
                RatingRow(title: "飼い主の満足度",     value: Double(item.evaluation.ownerSatisfaction), starSize: 18)
            }
            feedingPeriodSection()

            // コメント（編集可）＋ 公開設定
            VStack(alignment: .leading, spacing: 8) {
                Text("コメント").font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    // コメント本文（編集）
                    TextEditor(text: $editableComment)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )

                    // 公開設定（コメントの下に表示）
                    HStack {
                        Spacer()
                        Text(isReviewPublic ? "コメントを公開する" : "コメントを公開しない")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Toggle("", isOn: $isReviewPublic)
                            .labelsHidden()
                            .tint(FeedingBarColor.beige.color)
                            .scaleEffect(0.8, anchor: .center)
                    }
                }
            }

            // バーの色（メモの下に独立した項目として配置）
            barColorSection()

            // 一番下の「変更を保存」ボタン
            saveChangesButton()
            deleteButton()
        }
    }
    
    // MARK: - Feeding period edit section
    private func feedingPeriodSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.evaluation.dogName) が食べた期間")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                // 開始日
                DatePicker("食べ始めた日", selection: $feedingStart, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                
                // 終了日の有無
                Toggle("食べ終えた日を設定する", isOn: $hasEndDate.animation())
                    .tint(FeedingBarColor.beige.color)
                
                if hasEndDate {
                    DatePicker(
                        "食べ終えた日",
                        selection: Binding(
                            get: { feedingEnd ?? feedingStart },
                            set: { feedingEnd = $0 }
                        ),
                        in: feedingStart...,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                
                if let error = feedingPeriodError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
        }
    }
    
    private func saveFeedingPeriod() {
        guard let evalId = item.evaluation.id else {
            feedingPeriodError = "この評価はIDがないため、期間を保存できません。"
            return
        }
        feedingPeriodError = nil
        isSavingFeedingPeriod = true
        
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "feedingStartDate": Timestamp(date: feedingStart),
            "barColorKey": selectedBarColor.rawValue,
            "comment": editableComment,
            "isReviewPublic": isReviewPublic
        ]
        
        if hasEndDate, let end = feedingEnd {
            data["feedingEndDate"] = Timestamp(date: end)
        } else {
            // 終了日をクリアする場合は null を保存
            data["feedingEndDate"] = NSNull()
        }
        
        db.collection("evaluations").document(evalId).updateData(data) { error in
            DispatchQueue.main.async {
                isSavingFeedingPeriod = false
                if let error = error {
                    feedingPeriodError = "期間の保存に失敗しました: \(error.localizedDescription)"
                } else {
                    feedingPeriodError = nil
                    // 保存成功時は閉じて DogDetailView に戻る
                    withAnimation(.easeInOut) {
                        isPresented = false
                    }
                }
            }
        }
    }
    // 🔽 ここから追加：評価削除処理
    private func deleteEvaluation() {
        guard let evalId = item.evaluation.id else {
            feedingPeriodError = "この評価はIDがないため、削除できません。"
            return
        }
        feedingPeriodError = nil
        isDeleting = true

        let db = Firestore.firestore()
        db.collection("evaluations").document(evalId).delete { error in
            DispatchQueue.main.async {
                isDeleting = false
                if let error = error {
                    feedingPeriodError = "削除に失敗しました: \(error.localizedDescription)"
                } else {
                    // 削除成功時は画面を閉じる
                    withAnimation(.easeInOut) {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    

    // MARK: - Bar color section
    private func barColorSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("バーの色")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(FeedingBarColor.allCases) { option in
                    Button {
                        selectedBarColor = option
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(option.color.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selectedBarColor == option
                                        ? Color.black
                                        : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Bottom save button
    private func saveChangesButton() -> some View {
        Button {
            saveFeedingPeriod()
        } label: {
            if isSavingFeedingPeriod {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("変更を保存")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FeedingBarColor.beige.color)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .disabled(isSavingFeedingPeriod)
        .padding(.top, 8)
    }
    
    // MARK: - Delete button
    private func deleteButton() -> some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text(isDeleting ? "削除中..." : "記録を削除する")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .disabled(isDeleting)
        .padding(.top, 4)
    }
    
    
    private func dateStringJP(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy年M月d日（E）"
        return f.string(from: date)
    }
}

 #if canImport(UIKit)
 /// キーボードの高さを監視して、コンテンツを持ち上げるためのオブジェクト
 final class KeyboardObserver: ObservableObject {
     @Published var height: CGFloat = 0

     init() {
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleKeyboardWillShow(_:)),
             name: UIResponder.keyboardWillShowNotification,
             object: nil
         )
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleKeyboardWillHide(_:)),
             name: UIResponder.keyboardWillHideNotification,
             object: nil
         )
     }

     @objc private func handleKeyboardWillShow(_ notification: Notification) {
         guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
         height = frame.height
     }

     @objc private func handleKeyboardWillHide(_ notification: Notification) {
         height = 0
     }

     deinit {
         NotificationCenter.default.removeObserver(self)
     }
 }
 #endif

// MARK: - アレルギータグ（DogFoodDetailViewと同等スタイル）
private struct AllergyTagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .stroke(Color(.systemGray3))
            )
    }
}

// MARK: - DogFoodDetailView と同等の星UI（StarRatingView / RatingRow）
private struct EvalStarRatingView: View {
    let rating: Double          // 0.0〜5.0
    var size: CGFloat = 18
    var spacing: CGFloat = 4
    private let maxStars = 5
    var fillFromRight: Bool = false

    private var clampedRating: Double { max(0, min(rating, Double(maxStars))) }
    private var totalWidth: CGFloat { size * CGFloat(maxStars) + spacing * CGFloat(maxStars - 1) }
    private var fillWidth: CGFloat {
        let full = floor(clampedRating)
        let partial = clampedRating - full
        let fullWidth = CGFloat(full) * (size + spacing)
        let partialWidth = CGFloat(partial) * size
        return fullWidth + partialWidth
    }

    var body: some View {
        ZStack {
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable().scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.white)

            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable().scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.yellow)
            .frame(width: totalWidth, alignment: .leading)
            .mask(
                HStack(spacing: 0) {
                    if fillFromRight {
                        Spacer(minLength: 0)
                        Rectangle().frame(width: fillWidth)
                    } else {
                        Rectangle().frame(width: fillWidth)
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: totalWidth)
            )

            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star")
                        .resizable().scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.yellow)
        }
        .frame(width: totalWidth, height: size)
    }
}

private struct RatingRow: View {
    let title: String?
    let value: Double?
    var starSize: CGFloat = 18
    var numberWidth: CGFloat = 38

    private var formatted: String {
        guard let v = value else { return "" }
        return String(format: "%.1f", v)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title ?? "")
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text(formatted)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(width: numberWidth, alignment: .trailing)
                EvalStarRatingView(rating: value ?? 0, size: starSize)
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title ?? "平均評価")
        .accessibilityValue(formatted)
    }
}

private struct EvaluationDetailPreviewWrapper: View {
    @State private var isPresented = true
    let item: EvaluationWithFood

    var body: some View {
        EvaluationDetailView(item: item, isPresented: $isPresented)
    }
}

#Preview("EvaluationDetail – Mock") {
    // MocData からモックのドッグフード＆犬を取得
    let mockFood = PreviewMockData.dogFood[1]   // Hill's / プレミアムドッグ
    let mockDog  = PreviewMockData.dogs[0]      // ココ など

    // Evaluation は今までと同じパラメータでOK（必要な形に調整してもOK）
    let mockEval = Evaluation(
        id: "eval_preview",
        dogID: mockDog.id ?? "dog_preview",   // ← ここを修正
        dogName: mockDog.name,
        breed: mockDog.breed,
        dogFoodId: mockFood.id ?? "",
        userId: "user_001",
        overall: 4,
        dogSatisfaction: 5,
        ownerSatisfaction: 3,
        comment: "よく食べた。毛艶も良い感じ。",
        timestamp: Date(),
        ratings: [:]
    )

    let item = EvaluationWithFood(evaluation: mockEval, dogFood: mockFood)
    EvaluationDetailPreviewWrapper(item: item)
}
