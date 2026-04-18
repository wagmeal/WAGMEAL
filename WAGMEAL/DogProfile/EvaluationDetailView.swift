import SwiftUI
import FirebaseFirestore
import FirebaseAnalytics

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

    @EnvironmentObject var foodVM: DogFoodViewModel
    @EnvironmentObject var dogVM: DogProfileViewModel

    @Namespace private var namespace
    @State private var selectedDogFoodForDetail: DogFood? = nil
    @State private var showDogFoodDetail: Bool = false


    @State private var feedingStart: Date = Date()
    @State private var hasFeedingStartDate: Bool = true
    @State private var feedingEnd: Date?
    @State private var hasEndDate: Bool = false
    @State private var isSavingFeedingPeriod: Bool = false
    @State private var feedingPeriodError: String?
    @State private var selectedBarColor: FeedingBarColor = .beige

    @State private var editableComment: String = ""
    @State private var isReviewPublic: Bool = true
    
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false

    @State private var eatingRating: Int = 0            // 食いつき
    @State private var conditionRating: Int = 0         // 体調
    @State private var costPerformanceRating: Int = 0   // コスパ
    @State private var storageEaseRating: Int = 0       // 保存のしやすさ
    @State private var repurchaseRating: Int = 0        // また買いたい

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

    // MARK: - 犬の誕生日 / 年齢表示
    private var dogBirthDate: Date? {
        // DogProfileViewModel の dogs から評価対象の犬を特定
        dogVM.dogs.first(where: { ($0.id ?? "") == item.evaluation.dogID })?.birthDate
    }

    private func ageText(at date: Date) -> String {
        guard let birth = dogBirthDate else { return "年齢不明" }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: birth, to: date)
        let y = max(0, comps.year ?? 0)
        let m = max(0, comps.month ?? 0)
        if y <= 0 {
            return "\(m)ヶ月"
        }
        if m <= 0 {
            return "\(y)歳"
        }
        return "\(y)歳\(m)ヶ月"
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
                Analytics.logEvent("evaluation_detail_close", parameters: [
                    "evaluation_id": item.evaluation.id ?? "",
                    "food_id": item.dogFood.id ?? "",
                    "dog_id": item.evaluation.dogID
                ])
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

            // ✅ ドッグフード詳細画面（RankingViewと同じくZStackで上に重ねる）
            if let dogFood = selectedDogFoodForDetail, showDogFoodDetail {
                DogFoodDetailView(
                    dogFood: dogFood,
                    dogs: dogVM.dogs,
                    namespace: namespace,
                    matchedID: dogFood.id ?? UUID().uuidString,
                    isPresented: $showDogFoodDetail
                )
                .environmentObject(foodVM)
                .zIndex(1)
                .transition(.move(edge: .trailing))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width > 100 {
                                withAnimation {
                                    showDogFoodDetail = false
                                    selectedDogFoodForDetail = nil
                                }
                            }
                        }
                )
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "evaluation_detail",
                AnalyticsParameterScreenClass: "EvaluationDetailView"
            ])
            Analytics.logEvent("evaluation_detail_view", parameters: [
                "evaluation_id": item.evaluation.id ?? "",
                "food_id": item.dogFood.id ?? "",
                "dog_id": item.evaluation.dogID,
                "from_screen": "dog_detail"
            ])
            let ev = item.evaluation

            // 食べ始めた日（記録の有無を管理）
            if let start = ev.feedingStartDate {
                feedingStart = start
                hasFeedingStartDate = true
            } else {
                feedingStart = ev.timestamp
                hasFeedingStartDate = false
            }

            // 食べ終えた日（記録の有無を管理）
            feedingEnd = ev.feedingEndDate
            hasEndDate = feedingEnd != nil

            // コメント＆公開設定の初期値
            editableComment = ev.comment ?? ""
            isReviewPublic = ev.isReviewPublic ?? true

            eatingRating = ev.eating
            conditionRating = ev.condition
            costPerformanceRating = ev.costPerformance
            storageEaseRating = ev.storageEase
            repurchaseRating = ev.repurchase

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
        // (DogFoodDetailView sheet presentation removed; navigation handled via Search tab)
    }
    

    // MARK: - Small header image（優先順位：Storage -> Database(URL) -> imagefail2）
    private func smallHeaderImage() -> some View {
        ResolvedDogFoodImageView(
            storagePath: item.dogFood.storagePath,
            imagePath: item.dogFood.imagePath,
            taskID: item.dogFood.id ?? item.dogFood.imagePath
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ProgressView()
        } fallback: {
            Image("imagefail2")
                .resizable()
                .scaledToFill()
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
                    
                    HStack(alignment: .center, spacing: 1) {
                        // ドッグフード名 + 日付をひとまとめ
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.dogFood.name)
                                .font(.title)
                                .bold()
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // 評価日
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                Text(dateStringJP(item.evaluation.timestamp))
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }

                        // 右端：詳細ボタン
                        Button {
                            Analytics.logEvent("evaluation_detail_open_food", parameters: [
                                "evaluation_id": item.evaluation.id ?? "",
                                "food_id": item.dogFood.id ?? ""
                            ])

                            hideKeyboard()
                            withAnimation(.spring()) {
                                selectedDogFoodForDetail = item.dogFood
                                showDogFoodDetail = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("詳細")
                                Image(systemName: "chevron.right")
                                    .imageScale(.small)
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray3))
                            )
                            .foregroundColor(FeedingBarColor.beige.color)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                
                if let brand = item.dogFood.brand, !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag")
                        Text(brand)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(.subheadline)
                    //.foregroundColor(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                // 「また買いたい」を最初に表示
                VStack(alignment: .leading, spacing: 2) {
                    EditableRatingRow(title: "また買いたい", rating: $repurchaseRating)
                    Text("総合的に見てまた買いたいか")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    EditableRatingRow(title: "食いつき", rating: $eatingRating)
                    Text("食べるスピード・残しやすさ")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    EditableRatingRow(title: "体調", rating: $conditionRating)
                    Text("便・皮膚・涙やけ・元気さなど")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    EditableRatingRow(title: "コスパ", rating: $costPerformanceRating)
                    Text("価格に対する満足度")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    EditableRatingRow(title: "保存のしやすさ", rating: $storageEaseRating)
                    Text("袋・保管のしやすさなど")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
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
    
    // MARK: - Feeding period edit section（EvaluationInputView と同じ構成）
    private func feedingPeriodSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.evaluation.dogName) が食べた期間")
                .font(.headline)
            
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
                            .tint(FeedingBarColor.beige.color)
                            .scaleEffect(0.8, anchor: .center)
                    }
                }

                // 食べ始めた日ピッカー（記録する場合のみ表示）
                if hasFeedingStartDate {
                    HStack {
                        Text("その時の年齢：\(ageText(at: feedingStart))")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $feedingStart,
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
                        Text(hasEndDate ? "記録する" : "記録しない")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Toggle("", isOn: $hasEndDate)
                            .labelsHidden()
                            .tint(FeedingBarColor.beige.color)
                            .scaleEffect(0.8, anchor: .center)
                    }
                }

                // 食べ終えた日ピッカー（記録する場合のみ表示）
                if hasEndDate {
                    let endBinding = Binding(
                        get: { feedingEnd ?? feedingStart },
                        set: { feedingEnd = $0 }
                    )
                    HStack {
                        Text("その時の年齢：\(ageText(at: endBinding.wrappedValue))")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Spacer()
                        DatePicker(
                            "",
                            selection: endBinding,
                            in: feedingStart...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }

                // エラー表示
                if let error = feedingPeriodError {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func saveFeedingPeriod() {
        guard let evalId = item.evaluation.id else {
            feedingPeriodError = "この評価はIDがないため、期間を保存できません。"
            return
        }
        feedingPeriodError = nil
        Analytics.logEvent("evaluation_update_attempt", parameters: [
            "evaluation_id": evalId,
            "food_id": item.dogFood.id ?? "",
            "dog_id": item.evaluation.dogID,
            "eating": eatingRating,
            "condition": conditionRating,
            "cost_performance": costPerformanceRating,
            "storage_ease": storageEaseRating,
            "repurchase": repurchaseRating,
            "comment_filled": !editableComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "has_feeding_start": hasFeedingStartDate,
            "has_feeding_end": hasEndDate,
            "is_review_public": isReviewPublic,
            "bar_color": selectedBarColor.rawValue
        ])
        isSavingFeedingPeriod = true
        
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "barColorKey": selectedBarColor.rawValue,
            "comment": editableComment,
            "isReviewPublic": isReviewPublic,
            "eating": eatingRating,
            "condition": conditionRating,
            "costPerformance": costPerformanceRating,
            "storageEase": storageEaseRating,
            "repurchase": repurchaseRating,
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
            data["feedingStartDate"] = Timestamp(date: feedingStart)
        } else {
            // 記録しない場合はフィールドをクリア
            data["feedingStartDate"] = NSNull()
        }

        // 食べ終えた日
        if hasEndDate, let end = feedingEnd {
            data["feedingEndDate"] = Timestamp(date: end)
        } else {
            // 記録しない場合やトグルOFFの場合はフィールドをクリア
            data["feedingEndDate"] = NSNull()
        }
        
        db.collection("evaluations").document(evalId).updateData(data) { error in
            DispatchQueue.main.async {
                isSavingFeedingPeriod = false
                if let error = error {
                    feedingPeriodError = "期間の保存に失敗しました: \(error.localizedDescription)"
                } else {
                    feedingPeriodError = nil
                    Analytics.logEvent("evaluation_update", parameters: [
                        "evaluation_id": evalId,
                        "food_id": item.dogFood.id ?? "",
                        "dog_id": item.evaluation.dogID,
                        "eating": eatingRating,
                        "condition": conditionRating,
                        "cost_performance": costPerformanceRating,
                        "storage_ease": storageEaseRating,
                        "repurchase": repurchaseRating,
                        "comment_filled": !editableComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "has_feeding_start": hasFeedingStartDate,
                        "has_feeding_end": hasEndDate,
                        "is_review_public": isReviewPublic,
                        "bar_color": selectedBarColor.rawValue
                    ])
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
        Analytics.logEvent("evaluation_delete_attempt", parameters: [
            "evaluation_id": evalId,
            "food_id": item.dogFood.id ?? "",
            "dog_id": item.evaluation.dogID
        ])
        isDeleting = true

        let db = Firestore.firestore()
        db.collection("evaluations").document(evalId).delete { error in
            DispatchQueue.main.async {
                isDeleting = false
                if let error = error {
                    feedingPeriodError = "削除に失敗しました: \(error.localizedDescription)"
                } else {
                    Analytics.logEvent("evaluation_delete", parameters: [
                        "evaluation_id": evalId,
                        "food_id": item.dogFood.id ?? "",
                        "dog_id": item.evaluation.dogID
                    ])
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

    // MARK: - Keyboard
    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
        #endif
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

// MARK: - 編集可能な星評価行
private struct EditableRatingRow: View {
    let title: String
    @Binding var rating: Int
    var starSize: CGFloat = 22
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: starSize, height: starSize)
                        .foregroundColor(.yellow)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            rating = index
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    // MocData から既存の評価を1件取得
    let mock = PreviewMockData.evaluations.first!

    // 対応する DogFood を取得
    let mockFood = PreviewMockData.dogFood.first { $0.id == mock.dogFoodId }!

    // MockEvaluation → Evaluation へ変換
    let eval = Evaluation(fromMock: mock)

    let item = EvaluationWithFood(evaluation: eval, dogFood: mockFood)

    EvaluationDetailPreviewWrapper(item: item)
        .environmentObject(DogFoodViewModel(mockData: true))
        .environmentObject(DogProfileViewModel())
        .environmentObject(MainTabRouter())
}

