import SwiftUI
import FirebaseAuth
import FirebaseCore   // ← プレビューで初期化するため
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DogFoodDetailView2: View {
    let dogFood: DogFood
    let dogs: [DogProfile]
    let namespace: Namespace.ID
    let matchedID: String
    
    @StateObject private var evalVM: EvaluationViewModel
    
    @State private var isPresentingEvaluationInput = false
    @State private var selectedDogID: String?
    
    
    
    @EnvironmentObject var foodVM: DogFoodViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showRatings = false
    @State private var showIngredients = false
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

    
    var body: some View {
        ZStack(alignment: .top) {
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            headerImage()
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .edgesIgnoringSafeArea(.top)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Color.clear
                        .frame(height: UIScreen.main.bounds.height * 0.4)
                    
                    VStack(spacing: 20) {
                        infoSection()
                    }
                    .padding(.top, 16)
                    .background(Color.white)
                    .offset(y: 0)
                }
                .padding(.bottom, 100)
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
    
    
    // MARK: - Header image view
    private func headerImage() -> some View {
        ZStack {
            if let url = URL(string: dogFood.imagePath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .failure:
                        Image("imagefail2")
                            .resizable()
                            .scaledToFill()
                    @unknown default:
                        Image("imagefail2")
                            .resizable()
                            .scaledToFill()
                    }
                }
            } else {
                // URLが無い場合のフォールバック
                Image("imagefail2")
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: UIScreen.main.bounds.width)
        .clipped()
    }
    
    // MARK: - Info section
    private func infoSection() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dogFood.name)
                    .font(.title)
                    .bold()
                    .padding(.horizontal, 16)

                // アレルギー情報（左詰め・複数行折り返し）
                if !allergyItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        FlowLayout(spacing: 8) {
                            ForEach(allergyItems, id: \.self) { item in
                                AllergyTagView(text: item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            
            // ブランド表示（タグアイコン + ブランド名 / 文字は青）
            if !dogFood.brandDisplay.isEmpty {
                Button(action: {
                    withAnimation(.spring()) {
                        foodVM.search(byBrand: dogFood.brandDisplay)
                        isPresented = false
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

            // みんなの評価（DisclosureGroup内）
            let hasAvg = (evalVM.average != nil)
            VStack(alignment: .leading, spacing: 5) {
                
                RatingRow(title: "総合評価",
                          value: evalVM.average?.overall,
                          starSize: 18)
                
                RatingRow(title: "わんちゃんの満足度",
                          value: evalVM.average?.dogSatisfaction,
                          starSize: 18)
                
                RatingRow(title: "飼い主の満足度",
                          value: evalVM.average?.ownerSatisfaction,
                          starSize: 18)
                
                // データ未取得/未評価時だけ注記を表示
                if !hasAvg {
                    Text("まだ評価がありません")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)

            // ✅ 変更: DisclosureGroup をカスタム見出しに置き換え（矢印: 閉=▼/開=▲、右側余白）
            if let ingredients = dogFood.ingredients, !ingredients.isEmpty {
                VStack(spacing: 0) {
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1 / UIScreen.main.scale)
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20) // ← 数値で余白指定（例: 8pt）

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
                        .frame(height: 20) // ← 数値で余白指定（例: 8pt）
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1 / UIScreen.main.scale)

                    // 展開中の中身（灰色ラインから開く + 背景フルブリード）
                    if showIngredients {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 1 / UIScreen.main.scale)
                                .padding(.horizontal, -16)

                            VStack(alignment: .leading, spacing: 12) {
                                Text(ingredients)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)            // 中身の左右余白
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                Button(action: { withAnimation(.easeInOut) { showRatings.toggle() } }) {
                    HStack(spacing: 8) {
                        Text("みんなの評価")
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
                    .frame(height: 20) // ← 数値で余白指定（例: 8pt）

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1 / UIScreen.main.scale)

                // 展開中の中身（灰色ラインから開く + 背景フルブリード）
                if showRatings {
                    VStack(spacing: 0) {

                        VStack(alignment: .leading, spacing: 12) {
                            if let id = dogFood.id {
                                TopReviewsSection(
                                    dogFoodID: id,
                                    dogFood: dogFood,
                                    topReviews: evalVM.topReviews,
                                    totalCount: evalVM.totalReviewCount,
                                    dogs: dogs
                                )
                            } else {
                                Text("まだレビューがありません")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)            // 中身の左右余白
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6).allowsHitTesting(false))
                    }
                }
            }
            
            
            
            // 各種リンクセクション（折りたたみ）
            let hasAnyLink =
                (dogFood.homepageURL?.isEmpty == false) ||
                (dogFood.amazonURL?.isEmpty == false) ||
                (dogFood.yahooURL?.isEmpty == false) ||
                (dogFood.rakutenURL?.isEmpty == false)

            if hasAnyLink {
                VStack(spacing: 0) {
                    // 見出し（タップで開閉）
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
                    
                    // 展開中の中身
                    if showLinks {
                        VStack(spacing: 0) {
                            // 上部の細いグレーライン（フルブリード）
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 1 / UIScreen.main.scale)
                                .padding(.horizontal, -16)
                            
                            // 中身本体（灰色背景）
                            VStack(spacing: 0) {
                                // ホームページ
                                if let urlString = dogFood.homepageURL,
                                   !urlString.isEmpty,
                                   let url = URL(string: urlString) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        HStack {
                                            Text("ホームページ")
                                                .font(.body)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .imageScale(.small)
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                }
                                
                                // Amazon
                                if let urlString = dogFood.amazonURL,
                                   !urlString.isEmpty,
                                   let url = URL(string: urlString) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        HStack {
                                            Text("Amazon")
                                                .font(.body)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .imageScale(.small)
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                }
                                
                                // Yahoo!ショッピング
                                if let urlString = dogFood.yahooURL,
                                   !urlString.isEmpty,
                                   let url = URL(string: urlString) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        HStack {
                                            Text("Yahoo!ショッピング")
                                                .font(.body)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .imageScale(.small)
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                }
                                
                                // 楽天市場
                                if let urlString = dogFood.rakutenURL,
                                   !urlString.isEmpty,
                                   let url = URL(string: urlString) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        HStack {
                                            Text("楽天市場")
                                                .font(.body)
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .imageScale(.small)
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)           // 中身の左右余白
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                        }
                    }
                }
            }
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
                        .padding(14)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    isPresentingEvaluationInput = true
                }) {
                    HStack {
                        Spacer()
                        Text("評価を入力する")
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
    
    /// 0.0〜5.0 を「n.0 で n 個満タン」にする星表示
    /// 見た目：白塗りベース＋黄色アウトライン、右から黄色で充填
    private struct StarRatingView: View {
        let rating: Double          // 0.0〜5.0
        var size: CGFloat = 18
        var spacing: CGFloat = 4
        private let maxStars = 5
        var fillFromRight: Bool = false

        private var clampedRating: Double {
            max(0, min(rating, Double(maxStars)))
        }
        private var totalWidth: CGFloat {
            size * CGFloat(maxStars) + spacing * CGFloat(maxStars - 1)
        }
        /// ★「n.0でn個満タン」になる幅
        private var fillWidth: CGFloat {
            let full = floor(clampedRating)                 // 0,1,2,3,4,5
            let partial = clampedRating - full              // 0.0〜1.0
            // 完了した星の幅（星+隙間）＋ 部分星の幅（星の幅だけ）
            let fullWidth = CGFloat(full) * (size + spacing)
            let partialWidth = CGFloat(partial) * size
            return fullWidth + partialWidth
        }

        var body: some View {
            ZStack {
                // 1) 白塗りの星（土台）
                HStack(spacing: spacing) {
                    ForEach(0..<maxStars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                    }
                }
                .foregroundStyle(.white)

                // 2) 黄色の塗り（★ 右端起点。n.0 で n 個がちょうど満タン）
                HStack(spacing: spacing) {
                    ForEach(0..<maxStars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .scaledToFit()
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
                    .frame(width: totalWidth) // 星群と同じ幅
                )

                // 3) 黄色のアウトライン
                HStack(spacing: spacing) {
                    ForEach(0..<maxStars, id: \.self) { _ in
                        Image(systemName: "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                    }
                }
                .foregroundStyle(.yellow)
            }
            .frame(width: totalWidth, height: size) // 幅を固定して安定配置
        }
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

// MARK: - 行折り返しレイアウト（FlowLayout）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // 最大幅（提案があればそれを使い、なければ画面幅から余白を引く）
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width - 32

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(
                ProposedViewSize(width: maxWidth, height: .infinity)
            )

            if x + size.width > maxWidth {
                // 改行
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(
                ProposedViewSize(width: maxWidth, height: .infinity)
            )

            if x + size.width > maxWidth {
                // 改行
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

/// 1行で「左：タイトル」｜「右：数値＋星（右端寄せ）」を表示
    private struct RatingRow: View {
        let title: String?
        let value: Double?          // 0.0〜5.0
        var starSize: CGFloat = 18
        var numberWidth: CGFloat = 38
        
        private var formatted: String {
            guard let v = value else { return "" }
            return String(format: "%.1f", v)
        }
        
        var body: some View {
            HStack(spacing: 12) {
                // 左：タイトル（1行省略）
                Text(title ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 8)
                
                // 右端：数値＋星（セットで右寄せ）
                HStack(spacing: 8) {
                    Text(formatted)
                        .font(.headline)
                        .monospacedDigit()
                        .frame(width: numberWidth, alignment: .trailing)
                    
                    StarRatingView(rating: value ?? 0, size: starSize)
                }
                .fixedSize() // ★ 折り返さず塊で右端に
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title ?? "平均評価")
            .accessibilityValue(formatted)
        }
    }
}

// MARK: - ✅ 追加: トップレビュー（3件）＋ 全件遷移
private struct TopReviewsSection: View {
    let dogFoodID: String
    let dogFood: DogFood
    let topReviews: [Evaluation]
    let totalCount: Int
    let dogs: [DogProfile]
    @State private var showAll = false

    // 犬ID→プロフィールのマップ（年齢計算用）
    private var dogMap: [String: DogProfile] {
        Dictionary(uniqueKeysWithValues: dogs.compactMap { d in
            guard let id = d.id else { return nil }
            return (id, d)
        })
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 見出し（ここにはリンクを置かない）
            Text("最新のレビュー")
                .font(.headline)

            if topReviews.isEmpty {
                Text("まだレビューがありません")
                    .font(.footnote)
                    .foregroundColor(.gray)
            } else {
                let top3 = Array(topReviews.prefix(3))
                VStack(spacing: 30) {
                    // ★ レビュー3件を先に描画
                    ForEach(top3.indices, id: \.self) { idx in
                        let ev = top3[idx]
                        let ageText = ageTextForDog(id: ev.dogID, at: ev.timestamp)
                        ReviewCard(e: ev, ageText: ageText)
                    }

                    // ★ 3件の「下」にリンクを配置
                    if totalCount >= 4 {
                        Button {
                                showAll = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("すべての評価を見る（\(totalCount)件）")
                                    Image(systemName: "chevron.right").font(.subheadline)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showAll) {
                                NavigationStack {  // ここで戻るナビを持たせる
                                    AllEvaluationsView(dogFoodID: dogFoodID, dogFood: dogFood)
                                }
                            }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func ageTextForDog(id: String, at date: Date?) -> String? {
        guard let dog = dogMap[id] else { return nil }
        let referenceDate = date ?? Date()
        return formatAge(from: dog.birthDate, to: referenceDate)
    }

    private func formatAge(from birth: Date?, to now: Date) -> String? {
        guard let birth else { return nil }
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: birth, to: now)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        if y <= 0 && m <= 0 { return "0ヶ月" }
        if y > 0 && m > 0 { return "\(y)歳\(m)ヶ月" }
        if y > 0 { return "\(y)歳" }
        return "\(m)ヶ月"
    }
}

/// Shared, reusable read-only star view (Double rating).
internal struct ReadOnlyStarRatingView2: View {
    let rating: Double      // 0.0...5.0
    var size: CGFloat = 16
    private let maxStars = 5
    private var clamped: Double { max(0, min(rating, Double(maxStars))) }

    var body: some View {
        let spacing: CGFloat = 4
        let totalWidth = size * CGFloat(maxStars) + spacing * CGFloat(maxStars - 1)
        let full = floor(clamped)
        let partial = clamped - full
        let fillWidth = CGFloat(full) * (size + spacing) + CGFloat(partial) * size

        ZStack {
            // base (white-filled stars)
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.white)
                }
            }
            // yellow fill with mask
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.yellow)
                }
            }
            .frame(width: totalWidth, alignment: .leading)
            .mask(
                HStack(spacing: 0) {
                    Rectangle().frame(width: fillWidth)
                    Spacer(minLength: 0)
                }
                .frame(width: totalWidth)
            )
            // yellow outline
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .frame(width: totalWidth, height: size)
    }
}

// MARK: - ✅ 追加: レビューカード（ZOZO風サマリ）
internal struct ReviewCard2: View {
    let e: Evaluation
    var ageText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 評価（星のみ・数値なし）: 総合 / わんちゃん / 飼い主
            VStack(alignment: .leading, spacing: 8) {
                ratingRow(label: "総合評価", value: Double(e.overall))
                ratingRow(label: "わんちゃんの満足度", value: Double(e.dogSatisfaction))
                ratingRow(label: "飼い主の満足度", value: Double(e.ownerSatisfaction))
            }
            
            Divider()
                .background(Color(.systemGray4))
            
            // 本文（サマリ）
            if (e.isReviewPublic ?? true),
               let comment = e.comment,
               !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            
            VStack(alignment: .leading, spacing: 3) {
                // 犬種 | 年齢
                HStack(spacing: 8) {
                    if let ageText {
                        Text("\(e.breed) | \(ageText)")
                    } else {
                        Text(e.breed)
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                // 入力日（カード最下部）
                HStack {
                    Text(Self.fmtDate(e.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.white))
        )
    }

    // 星のみ表示の評価行
    private func ratingRow(label: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer(minLength: 8)
            // 星のみ表示（数値なし）
            ReadOnlyStarRatingView(rating: value, size: 16)
        }
    }

    private static func fmtDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: d)
    }
}



// MARK: - Previews

/// Firebase を初期化して実際に Storage から読むプレビュー
struct DogFoodDetailViewPreviewBoot2: View {
    @Namespace var namespace
    @State private var isPresented = true

    init() {
        if FirebaseApp.app() == nil {
            // App Check を Enforce している場合は必要に応じて有効化
            // AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            FirebaseApp.configure()
        }
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
    }
}

#Preview("DogFoodDetail – 実読込") {
    DogFoodDetailViewPreviewBoot()
}


