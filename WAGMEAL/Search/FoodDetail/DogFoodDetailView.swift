import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseCore   // ← プレビューで初期化するため
import FirebaseFirestore
import FirebaseAnalytics



struct DogFoodDetailView: View {
    let dogFood: DogFood
    let dogs: [DogProfile]
    let namespace: Namespace.ID
    let matchedID: String
    
    // MARK: - Preview判定（Xcode Previewsでは重い処理を避ける）
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    @StateObject private var evalVM: EvaluationViewModel
    
    @State private var isPresentingEvaluationInput = false
    @State private var selectedDogID: String?
    
    
    
    @EnvironmentObject var foodVM: DogFoodViewModel
    @EnvironmentObject var tabRouter: MainTabRouter   // ← 追加
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showRatings = false
    @State private var showIngredients = false
    @State private var showNutrients = false
    @State private var showLinks = false
    @Binding var isPresented: Bool
    
    // ✅ 追加: evalVM を注入できる init（既存の呼び出し互換）
       init(
           dogFood: DogFood,
           dogs: [DogProfile],
           namespace: Namespace.ID,
           matchedID: String,
           evalVM: EvaluationViewModel = EvaluationViewModel(),
           isPresented: Binding<Bool>
       ) {
           self.dogFood = dogFood
           self.dogs = dogs
           self.namespace = namespace
           self.matchedID = matchedID
           self._isPresented = isPresented
           // ここがポイント：StateObject の wrappedValue を一度だけ作る
           _evalVM = StateObject(wrappedValue: evalVM)
       }

    // MARK: - アレルギー情報（フラグからラベルを生成）
    private var allergyItems: [String] {
        var items: [String] = []
        if dogFood.hasChicken ?? false { items.append("鶏肉") }
        if dogFood.hasBeef ?? false { items.append("牛肉") }
        if dogFood.hasPork ?? false { items.append("豚肉") }
        if dogFood.hasLamb ?? false { items.append("ラム／羊") }
        if dogFood.hasFish ?? false { items.append("魚") }
        if dogFood.hasEgg ?? false { items.append("卵") }
        if dogFood.hasDairy ?? false { items.append("乳製品") }
        if dogFood.hasWheat ?? false { items.append("小麦") }
        if dogFood.hasCorn ?? false { items.append("トウモロコシ") }
        if dogFood.hasSoy ?? false { items.append("大豆") }
        return items
    }

    private var allergyText: String? {
        let items = allergyItems
        guard !items.isEmpty else { return nil }
        return items.joined(separator: "・")
    }

    // MARK: - 原材料テキストの「検出用語」を下線（＋太字）でハイライト
    private var activeAllergyKeywords: [String] {
        var keys: [String] = []

        // 鶏肉系
        if dogFood.hasChicken ?? false {
            keys += [
                "鶏肉","鶏","チキン","チキンミール","チキンエキス",
                "chicken","chicken meal","chicken by-product","chicken by-product meal"
            ]
        }

        // 牛肉系
        if dogFood.hasBeef ?? false {
            keys += [
                "牛肉","牛","ビーフ","beef","beef meal","beef by-product","beef by-product meal"
            ]
        }

        // 豚肉系
        if dogFood.hasPork ?? false {
            keys += [
                "豚肉","豚","ポーク","pork","pork meal","pork by-product","pork by-product meal"
            ]
        }

        // ラム系
        if dogFood.hasLamb ?? false {
            keys += [
                "ラム","羊肉","羊","ラムミール",
                "マトン","mutton",
                "lamb","lamb meal"
            ]
        }

        // 魚系
        if dogFood.hasFish ?? false {
            keys += [
                "魚","魚介","魚介類","魚粉","魚肉","魚肉粉",
                "フィッシュ","フィッシュミール","fish","fish meal",
                "まぐろ","マグロ","tuna","ツナ",
                "かつお","カツオ",
                "サーモン","鮭","salmon",
                "タラ","cod",
                "鯛","タイ",
                "白身魚","whitefish","ホワイトフィッシュ",
                "オーシャンフィッシュ","ocean fish",
                "イワシ","いわし",
                "ニシン",
                "サバ",
                "カレイ",
                "ホキ",
                "マス",
                "トラウト",
                "ブリ",
                "アンチョビ",
                "オキアミ"
            ]
        }

        // 卵系
        if dogFood.hasEgg ?? false {
            keys += [
                "卵","全卵","卵黄","卵白","卵粉","乾燥卵",
                "エッグ","エッグパウダー",
                "egg","whole egg","dried egg","egg product","egg yolk","egg white"
            ]
        }

        // 乳製品系（※乳酸菌は乳製品として扱わない）
        if dogFood.hasDairy ?? false {
            keys += [
                "乳製品","ミルク","milk","skim milk","脱脂粉乳","全脂粉乳",
                "乳清","ホエイ","ホエイパウダー","whey",
                "カゼイン","casein",
                "チーズ","cheese",
                "ヨーグルト","yogurt",
                "バター","butter",
                "クリーム","cream",
                "バターミルク","buttermilk",
                "乳糖","ラクトース","lactose",
                "ミルクプロテイン","milk protein","milk protein concentrate"
            ]
        }

        // 小麦系
        if dogFood.hasWheat ?? false {
            keys += [
                "小麦","小麦粉","全粒小麦","小麦胚芽","小麦ふすま","小麦ブラン",
                "パン粉",
                "グルテン","小麦グルテン",
                "wheat","wheat flour","gluten","wheat gluten"
            ]
        }

        // トウモロコシ系
        if dogFood.hasCorn ?? false {
            keys += [
                "トウモロコシ","とうもろこし",
                "コーン","corn",
                "コーンミール","corn meal","cornmeal",
                "コーンスターチ","corn starch",
                "コーンフラワー",
                "コーングルテン","corn gluten",
                "コーングルテンミール","corn gluten meal",
                "コーングルテンフィード"
            ]
        }

        // 大豆系
        if dogFood.hasSoy ?? false {
            keys += [
                "大豆","ダイズ",
                "脱脂大豆",
                "大豆たん白","大豆タンパク","大豆蛋白",
                "大豆油",
                "豆乳",
                "おから",
                "大豆レシチン","soy lecithin",
                "soy","soybean","soy bean",
                "soy meal","soybean meal",
                "soy protein","soy protein isolate"
            ]
        }

        // 重複削除 + 長い語を優先（重なりを減らす）
        return Array(Set(keys))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.count > $1.count }
    }

    private func highlightedIngredients(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = .body

        let base = String(attributed.characters)
        guard !base.isEmpty, !activeAllergyKeywords.isEmpty else {
            return attributed
        }

        for keyword in activeAllergyKeywords {
            let pattern = NSRegularExpression.escapedPattern(for: keyword)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let matches = regex.matches(in: base, range: NSRange(base.startIndex..., in: base))
            for m in matches {
                guard let r = Range(m.range, in: attributed) else { continue }
                attributed[r].underlineStyle = .single
                attributed[r].font = .body.bold()
            }
        }

        return attributed
    }

    
    // MARK: - 成分値表示用
    private func nutrientRow(title: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            if let v = value {
                // 表示桁数:
                // - カロリー(kcal/100g) と 水分(%) は小数点第1位
                // - それ以外(%) は小数点第2位
                let fmt = (unit == "kcal/100g" || title == "水分") ? "%.1f" : "%.2f"
                Text("\(String(format: fmt, v))\(unit)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            } else {
                Text("―")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
                .edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 20) {
                        infoSection()
                    }
                    .padding(.top, 16)
                    .background(Color.white)
                    .offset(y: 0)
                }
                .padding(.bottom, 100)
            }
            .refreshable {
                // PreviewsではFirestore/Networkを叩かない
                guard !isPreview else { return }

                if let id = dogFood.id {
                    // 評価関連の情報を最新化
                    evalVM.fetchAverages(for: id)
                    evalVM.listenTopReviews(for: id, limit: 3)
                    evalVM.fetchReviewCount(for: id)
                }
            }
            
            VStack {
                Spacer()
                alignedFooter()
            }
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .onAppear {
            // PreviewsではAnalytics/Firestoreを叩かない（タイムアウト対策）
            if isPreview {
                if selectedDogID == nil, let first = dogs.first {
                    selectedDogID = first.id
                }
                return
            }
            // ✅ 追加：画面表示イベント
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "dog_food_detail",
                AnalyticsParameterScreenClass: "DogFoodDetailView"
            ])

            if let id = dogFood.id {
                evalVM.fetchAverages(for: id)
                evalVM.listenTopReviews(for: id, limit: 3)
                evalVM.fetchReviewCount(for: id)
            }
            if selectedDogID == nil, let first = dogs.first {
                selectedDogID = first.id
            }
        }
        .task(id: dogFood.id ?? dogFood.imagePath) {
            // PreviewsではFirestore/Networkを叩かない（タイムアウト対策）
            guard !isPreview else { return }

            // 評価平均も選択ごとに再取得
            if let id = dogFood.id {
                evalVM.fetchAverages(for: id)
                evalVM.listenTopReviews(for: id, limit: 3)
                evalVM.fetchReviewCount(for: id)
            }
        }
        .sheet(isPresented: $isPresentingEvaluationInput) {
            NavigationStack {
                if let id = dogFood.id {
                    EvaluationInputView(
                        dogFoodID: id,
                        dogs: dogs,
                        selectedDogID: $selectedDogID
                    )
                }
            }
        }
    }
    
    
    // MARK: - Header image view（優先順位：Storage -> Database(URL) -> imagefail2）
    @ViewBuilder
    private func headerImage() -> some View {
        if isPreview {
            Image("imagefail2")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        } else {
            ResolvedDogFoodImageView(
                storagePath: dogFood.storagePath,
                imagePath: dogFood.imagePath,
                taskID: dogFood.id ?? dogFood.imagePath
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
    }
    
    // MARK: - Info subviews (compiler performance)
    @ViewBuilder private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                headerImage()
                Text(dogFood.name)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)

            if !allergyItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    TagFlowLayout(spacing: 8) {
                        ForEach(allergyItems, id: \.self) { item in
                            AllergyTagView(text: item)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder private var brandBlock: some View {
        if !dogFood.brandDisplay.isEmpty {
            Button(action: {
                withAnimation(.spring()) {
                    foodVM.showAllFoodsFromBrandExplorer = false
                    foodVM.search(byBrand: dogFood.brandDisplay)
                    foodVM.isSearchActive = false
                    tabRouter.selectedTab = .search
                    isPresented = false
                }

                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil,
                                                    from: nil,
                                                    for: nil)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .foregroundColor(.blue)
                    Text(dogFood.brandDisplay)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var ratingSummaryBlock: some View {
        let hasAvg = (evalVM.average != nil)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                RatingRow(title: "また買いたい", value: evalVM.average?.repurchase, starSize: 18)
                Text("総合的に見てまた買いたいか")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                RatingRow(title: "食いつき", value: evalVM.average?.eating, starSize: 18)
                Text("食べるスピード・残しやすさ")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                RatingRow(title: "体調", value: evalVM.average?.condition, starSize: 18)
                Text("便・皮膚・涙やけ・元気さなど")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                RatingRow(title: "コスパ", value: evalVM.average?.costPerformance, starSize: 18)
                Text("価格に対する満足度")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                RatingRow(title: "保存のしやすさ", value: evalVM.average?.storageEase, starSize: 18)
                Text("袋・保管のしやすさなど")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            if !hasAvg {
                Text("まだ評価がありません")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Info section parts
    @ViewBuilder
    private func ingredientsSection() -> some View {
        if let ingredients = dogFood.ingredients, !ingredients.isEmpty {
            VStack(spacing: 0) {

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1 / UIScreen.main.scale)

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                // 見出し（タップで開閉）
                Button(action: { withAnimation(.easeInOut) { showIngredients.toggle() } }) {
                    HStack(spacing: 8) {
                        Text("原材料")
                            .font(.headline)
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1 / UIScreen.main.scale)

                // 展開中の中身
                if showIngredients {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.horizontal, -16)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(highlightedIngredients(ingredients))
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("最新情報はホームページをご確認ください")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nutrientsSection() -> some View {
        let hasAny =
            dogFood.protein != nil
            || dogFood.fat != nil
            || dogFood.fiber != nil
            || dogFood.ash != nil
            || dogFood.moisture != nil
            || dogFood.calories != nil

        if hasAny {
            VStack(spacing: 0) {

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                // 見出し（タップで開閉）
                Button(action: { withAnimation(.easeInOut) { showNutrients.toggle() } }) {
                    HStack(spacing: 8) {
                        Text("成分値")
                            .font(.headline)
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: showNutrients ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1 / UIScreen.main.scale)

                if showNutrients {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.horizontal, -16)

                        VStack(alignment: .leading, spacing: 12) {
                            nutrientRow(title: "代謝エネルギー", value: dogFood.calories, unit: "kcal/100g")
                            nutrientRow(title: "(粗)タンパク質", value: dogFood.protein, unit: "%")
                            nutrientRow(title: "(粗)脂質", value: dogFood.fat, unit: "%")
                            nutrientRow(title: "(粗)繊維", value: dogFood.fiber, unit: "%")
                            nutrientRow(title: "(粗)灰分", value: dogFood.ash, unit: "%")
                            nutrientRow(title: "水分", value: dogFood.moisture, unit: "%")

                            Text("成分値は最大値、または最小値です。詳細はホームページを参照ください")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                    }
                }
            }
            // 親VStack(spacing: 20) の隙間を打ち消す（原材料との間の余白対策）
            .padding(.top, -20)
        }
    }

    // MARK: - Info section
    private var hasAnyLink: Bool {
        (dogFood.homepageURL?.isEmpty == false) ||
        (dogFood.amazonURL?.isEmpty == false) ||
        (dogFood.yahooURL?.isEmpty == false) ||
        (dogFood.rakutenURL?.isEmpty == false)
    }
    
    @ViewBuilder
    private func ratingsSection() -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut) { showRatings.toggle() } }) {
                HStack(spacing: 8) {
                    Text("みんなの評価（\(evalVM.totalReviewCount)）")
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: showRatings ? "chevron.up" : "chevron.down")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.clear)
                .frame(height: 20)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1 / UIScreen.main.scale)

            if showRatings {
                VStack(alignment: .leading, spacing: 12) {
                    if let id = dogFood.id {
                        TopReviewsSection(
                            dogFoodID: id,
                            dogFood: dogFood,
                            topReviews: evalVM.topReviews,
                            totalCount: evalVM.totalReviewCount
                        )
                    } else {
                        Text("まだレビューがありません")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
            }
        }
    }
    
    /// 購入リンクの行を生成する共通ヘルパー
    /// - Parameters:
    ///   - label: 表示名（例: "Amazon"）
    ///   - urlString: リンク先URL文字列（nilまたは空の場合は何も表示しない）
    ///   - destination: Analytics用の識別子（nilならイベント送信なし）
    ///   - showDivider: 行の下にDividerを表示するか（最終行はfalse）
    @ViewBuilder
    private func purchaseLinkRow(label: String, urlString: String?, destination: String?, showDivider: Bool = true) -> some View {
        if let urlString, !urlString.isEmpty, let url = URL(string: urlString) {
            Button {
                if let destination {
                    #if canImport(FirebaseAnalytics)
                    Analytics.logEvent("outbound_click", parameters: [
                        "food_id": dogFood.id ?? "",
                        "destination": destination
                    ])
                    #endif
                }
                openURL(url) { accepted in
                    if !accepted { UIApplication.shared.open(url) }
                }
            } label: {
                HStack {
                    Text(label).font(.body)
                    Spacer()
                    Image(systemName: "arrow.up.right.square").imageScale(.small)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if showDivider { Divider() }
        }
    }

    @ViewBuilder
    private func linksSection() -> some View {
        if hasAnyLink {
            VStack(spacing: 0) {
                Button(action: { withAnimation(.easeInOut) { showLinks.toggle() } }) {
                    HStack(spacing: 8) {
                        Text("各種リンク")
                            .font(.headline)
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: showLinks ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1 / UIScreen.main.scale)

                if showLinks {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.horizontal, -16)

                        VStack(spacing: 0) {
                            purchaseLinkRow(label: "ホームページ",    urlString: dogFood.homepageURL, destination: nil)
                            purchaseLinkRow(label: "Amazon",          urlString: dogFood.amazonURL,   destination: "amazon")
                            purchaseLinkRow(label: "Yahoo!ショッピング", urlString: dogFood.yahooURL,  destination: "yahoo")
                            purchaseLinkRow(label: "楽天市場",        urlString: dogFood.rakutenURL,  destination: "rakuten", showDivider: false)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                    }
                }
            }
        }
    }
    
    // MARK: - Info section
    @ViewBuilder
    private func infoSection() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            headerBlock
            brandBlock
            ratingSummaryBlock

            ingredientsSection()
            nutrientsSection()

            ratingsSection()
            linksSection()
        }
    }
    
    // MARK: - Footer
    private func alignedFooter() -> some View {
        VStack {
            Divider()
            HStack {
                // 左下バツボタン
                Button(action: {
                    withAnimation(.easeInOut) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(Color(.systemGray))
                        .padding(14)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    // ✅ 追加：評価入力開始
                    Analytics.logEvent("evaluation_start", parameters: [
                        "food_id": dogFood.id ?? "",
                        "from_screen": "dog_food_detail"
                    ])
                    isPresentingEvaluationInput = true
                }) {
                    HStack {
                        Spacer()
                        Text("記録をつける")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    if let id = dogFood.id {
                        // ✅ 追加：お気に入りトグル
                        Analytics.logEvent("favorite_toggle", parameters: [
                            "food_id": id,
                            "is_favorite": !foodVM.isFavorite(id),
                            "from_screen": "dog_food_detail"
                        ])
                        foodVM.toggleFavorite(dogFoodID: id)   // ← VMに丸投げ（userIDはVMが持つ）
                    }
                }) {
                    Image(systemName: isFavoriteFromVM ? "heart.fill" : "heart")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .padding(10)
                        .foregroundColor(.red)
                }
                
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }
    
    private var isFavoriteFromVM: Bool {
        foodVM.isFavorite(dogFood.id)      // ← VMのAPIを使う（実装の隠蔽）
    }
    

    
    // MARK: - アレルギータグ
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

}



// MARK: - Previews

/// Firebase を初期化して実際に Storage から読むプレビュー
struct DogFoodDetailViewPreviewBoot: View {
    @Namespace var namespace
    @State private var isPresented = true

    init() {
        // PreviewsではFirebase初期化を行わない（タイムアウト原因になりやすい）
    }

    var body: some View {
        DogFoodDetailView(
            dogFood: PreviewMockData.dogFood.first!,
            dogs: PreviewMockData.dogs,
            namespace: namespace,
            matchedID: PreviewMockData.dogFood.first!.id ?? "preview_dogfood_id",
            evalVM: MockEvaluationViewModel.shared,
            isPresented: $isPresented
        )
        .environmentObject(DogFoodViewModel(mockData: true))
        .environmentObject(MainTabRouter())
    }
}

//#Preview("DogFoodDetail – 実読込") {
//    DogFoodDetailViewPreviewBoot()
//}



