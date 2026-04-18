import SwiftUI
import FirebaseAnalytics

struct RankingView: View {
    @EnvironmentObject var foodVM: DogFoodViewModel
    @EnvironmentObject var dogVM: DogProfileViewModel
    
    @Namespace private var namespace
    @State private var selectedDogFood: DogFood? = nil
    @State private var showDetail = false
    @State private var failedFoodImagePaths: Set<String> = []
    @State private var imageReloadKey = UUID()
    @State private var evaluationCountReloadKey = UUID() // 件数だけ再取得するキー（セルを作り直さない）
    @State private var selectedSizeCategory: String? = nil // nil = 全体
    @State private var selectedDogID: String? = nil
    @State private var isShowingFilter = false
    @State private var isEditingFilters = false
    @State private var includeIngredientFilters: Set<IngredientFilter> = []
    @State private var excludeIngredientFilters: Set<IngredientFilter> = []

    // 新フィルタ（検索と同じ：フード種類 + 数値）
    @State private var foodTypeFilter: FoodTypeFilter = .all
    @State private var caloriesFilter: NumericFilter = .disabled()
    @State private var proteinFilter: NumericFilter = .disabled()
    @State private var fatFilter: NumericFilter = .disabled()
    @State private var fiberFilter: NumericFilter = .disabled()
    @State private var ashFilter: NumericFilter = .disabled()
    @State private var moistureFilter: NumericFilter = .disabled()
    
    // 👇 モック使用フラグを外から渡す
    var useMockData: Bool = false
    @StateObject private var rankingVM: RankingViewModel
    
    init(useMockData: Bool = false) {
        self.useMockData = useMockData
        _rankingVM = StateObject(wrappedValue: RankingViewModel(useMockData: useMockData))
    }
    
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // 現在選択されているわんちゃん
    private var selectedDog: DogProfile? {
        guard let id = selectedDogID else { return nil }
        return dogVM.dogs.first { $0.id == id }
    }

    // フィルターが「かかっている」状態かどうか
    private var isFiltering: Bool {
        let hasIngredient = !includeIngredientFilters.isEmpty || !excludeIngredientFilters.isEmpty
        let hasFoodType = foodTypeFilter != .all
        let hasNutrients =
            caloriesFilter.isEnabled
         || proteinFilter.isEnabled
         || fatFilter.isEnabled
         || fiberFilter.isEnabled
         || ashFilter.isEnabled
         || moistureFilter.isEnabled
        return (selectedDogID != nil) || hasIngredient || hasFoodType || hasNutrients
    }

    private func sizeCategoryFromDog(_ dog: DogProfile?) -> String? {
        // Dog 未選択なら全体
        guard let dog else { return nil }

        // DogProfile.sizeCategory が non-optional String の前提
        let size = dog.sizeCategory

        // 既存の保存形式に合わせてマッピング
        // 例: size が "小型犬" / "中型犬" / "大型犬" を持っている想定
        if ["小型犬", "中型犬", "大型犬"].contains(size) {
            return size
        }

        // もし別名で保存されている場合はここで吸収
        // (例: "small" / "middle" / "big")
        let raw = size.lowercased()
        switch raw {
        case "small": return "小型犬"
        case "middle", "medium": return "中型犬"
        case "big", "large": return "大型犬"
        default:
            return nil
        }
    }

    private func applyAllergyFilters(for dog: DogProfile?) {
        guard let dog else {
            // 犬未選択時：犬由来の exclude を解除（include はユーザー操作を尊重）
            excludeIngredientFilters = []
            return
        }
        excludeIngredientFilters = dog.allergyFilters
        // 犬由来フィルターでは include は使わない
        includeIngredientFilters.removeAll()
    }

    private func matchesIngredientFilters(food: DogFood) -> Bool {
        // include: すべて含む
        if !includeIngredientFilters.isEmpty {
            for f in includeIngredientFilters {
                if !food.contains(f) { return false }
            }
        }
        // exclude: すべて含まない
        if !excludeIngredientFilters.isEmpty {
            for f in excludeIngredientFilters {
                if food.contains(f) { return false }
            }
        }
        return true
    }

    private func matchesFoodTypeFilter(food: DogFood) -> Bool {
        switch foodTypeFilter {
        case .all: return true
        case .dry: return food.foodType == .dry
        case .wet: return food.foodType == .wet
        }
    }

    private func matchesNumeric(_ value: Double?, filter: NumericFilter) -> Bool {
        guard filter.isEnabled else { return true }   // 未適用ならOK
        guard let v = value else { return false }     // 条件があるのに値なしは除外

        if let minV = filter.minValue, v < minV { return false }
        if let maxV = filter.maxValue, v > maxV { return false }
        return true
    }

    private func matchesNutrientFilters(food: DogFood) -> Bool {
        matchesNumeric(food.calories, filter: caloriesFilter)
        && matchesNumeric(food.protein, filter: proteinFilter)
        && matchesNumeric(food.fat, filter: fatFilter)
        && matchesNumeric(food.fiber, filter: fiberFilter)
        && matchesNumeric(food.ash, filter: ashFilter)
        && matchesNumeric(food.moisture, filter: moistureFilter)
    }

    private func matchesAllFilters(food: DogFood) -> Bool {
        matchesIngredientFilters(food: food)
        && matchesFoodTypeFilter(food: food)
        && matchesNutrientFilters(food: food)
    }
    // rankedDogFoods 自体は Equatable ではないので、ID 配列（Equatable）で変更検知する
    private var rankedFoodIDs: [String] {
        rankingVM.rankedDogFoods.compactMap { $0.dogFood.id }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // タイトル
                Text(rankingTitle())
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)

                // フィルター
                sizeCategoryFilterIcons()

                // 🐶 わんちゃん選択 & 成分フィルタ（検索と同じ）
                DogSelectorBar(
                    dogs: dogVM.dogs,
                    selectedDogID: $selectedDogID,
                    isFiltering: isFiltering,
                    onTapFilter: { isShowingFilter = true }
                )
                .padding(.top, 4)

                ActiveFilterSummaryView(
                    include: includeIngredientFilters,
                    exclude: excludeIngredientFilters,
                    foodType: foodTypeFilter,
                    caloriesFilter: caloriesFilter,
                    proteinFilter: proteinFilter,
                    fatFilter: fatFilter,
                    fiberFilter: fiberFilter,
                    ashFilter: ashFilter,
                    moistureFilter: moistureFilter
                )

                // ランキング一覧だけスクロール
                rankingListSection
                    .padding(.top, 8)
            }

            // ✅ ドッグフード詳細画面（ZStackで上に重ねる）
            if let dogFood = selectedDogFood, showDetail {
                DogFoodDetailView(
                    dogFood: dogFood,
                    dogs: dogVM.dogs,
                    namespace: namespace,
                    matchedID: dogFood.id ?? UUID().uuidString,
                    isPresented: $showDetail
                )
                .environmentObject(foodVM)
                .zIndex(1)
                .transition(.move(edge: .trailing))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width > 100 {
                                withAnimation {
                                    showDetail = false
                                    selectedDogFood = nil
                                }
                            }
                        }
                )
            }
        }
        .onChange(of: selectedSizeCategory) { newValue in
            Analytics.logEvent("ranking_filter_change", parameters: [
                "size_category": newValue ?? "all"
            ])
            rankingVM.refresh(sizeCategory: newValue)
        }
        .onChange(of: selectedDogID) { _ in
            guard !isEditingFilters else { return }

            // 犬のアレルギーで成分フィルターを適用
            applyAllergyFilters(for: selectedDog)

            // 犬のサイズカテゴリも同時に適用（小/中/大）
            let newSize = sizeCategoryFromDog(selectedDog)

            Analytics.logEvent("ranking_dog_change", parameters: [
                "dog_selected": selectedDogID != nil,
                "size_category": newSize ?? "all"
            ])

            // selectedSizeCategory の onChange が refresh を呼ぶので、
            // サイズが変わる場合はここでは refresh しない（2回呼び防止）
            if newSize != selectedSizeCategory {
                selectedSizeCategory = newSize
            } else {
                rankingVM.refresh(sizeCategory: selectedSizeCategory)
            }
        }
        .sheet(isPresented: $isShowingFilter) {
            FilterSheetView(
                include: $includeIngredientFilters,
                exclude: $excludeIngredientFilters,

                foodTypeFilter: $foodTypeFilter,

                caloriesFilter: $caloriesFilter,
                proteinFilter: $proteinFilter,
                fatFilter: $fatFilter,
                fiberFilter: $fiberFilter,
                ashFilter: $ashFilter,
                moistureFilter: $moistureFilter,

                selectedDog: selectedDog,
                onUseDogAllergy: { dog in
                    excludeIngredientFilters = dog.allergyFilters
                    includeIngredientFilters.removeAll()
                }
            )
            .onAppear { isEditingFilters = true }
            .onDisappear { isEditingFilters = false }
        }
        .onChange(of: rankedFoodIDs) { ids in
            // ランキングで表示対象のIDだけ評価件数キャッシュをリセットして取り直す
            guard !ids.isEmpty else { return }
            foodVM.resetEvaluationCountCache(only: ids)
            ids.forEach { id in
                foodVM.loadEvaluationCountIfNeeded(for: id)
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "ranking",
                AnalyticsParameterScreenClass: "RankingView"
            ])
            Analytics.logEvent("ranking_view", parameters: [
                "size_category": selectedSizeCategory ?? "all"
            ])

            // 初回表示時も「犬選択 → サイズ絞り込み」の整合をとる
            selectedSizeCategory = sizeCategoryFromDog(selectedDog)
            rankingVM.refresh(sizeCategory: selectedSizeCategory)
            applyAllergyFilters(for: selectedDog)
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.bottom)
    }

    private var rankingListSection: some View {
        ScrollView {
            if rankingVM.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if rankingVM.rankedDogFoods.isEmpty {
                VStack {
                    Spacer().frame(height: 80)
                    Text("評価されたドッグフードがありません")
                        .foregroundColor(.gray)
                        .font(.body)
                        .frame(maxWidth: .infinity)
                }
            } else {
                rankingGrid(items: filteredRankingItems)
                    .padding(.bottom, 16)
            }
        }
        .refreshable {
            await refreshRankingLight()
        }
    }

    private var filteredRankingItems: [RankingViewModel.RankedDogFood] {
        rankingVM.rankedDogFoods.filter { matchesAllFilters(food: $0.dogFood) }
    }

    @ViewBuilder
    private func rankingGrid(items: [RankingViewModel.RankedDogFood]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items.indices, id: \.self) { idx in
                let item = items[idx]
                let matchedID = item.dogFood.id ?? "rank-\(idx)"
                let rank = idx + 1

                dogFoodCard(
                    item.dogFood,
                    averageRating: item.averageRating,
                    matchedID: matchedID,
                    rank: rank
                ) {
                    withAnimation(.spring()) {
                        Analytics.logEvent("food_view", parameters: [
                            "food_id": item.dogFood.id ?? "",
                            "from_screen": "ranking",
                            "size_category": selectedSizeCategory ?? "all",
                            "rank": rank
                        ])
                        selectedDogFood = item.dogFood
                        showDetail = true
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - フィルターUI（アイコン切替式）
    private func sizeCategoryFilterIcons() -> some View {
        HStack(spacing: 0) {
            ForEach(["小型犬", "中型犬", "大型犬"], id: \.self) { size in
                Button {
                    withAnimation {
                        if selectedSizeCategory == size {
                            selectedSizeCategory = nil // 選択解除で全体に戻す
                        } else {
                            selectedSizeCategory = size
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(filterIconName(for: size))
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 最後の要素以外に区切り線を追加
                if size != "大型犬" {
                    Divider()
                        .frame(width: 1, height: 50)
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func filterIconName(for category: String) -> String {
        switch category {
        case "小型犬":
            return selectedSizeCategory == "小型犬" ? "smalldogselected" : "smalldogunselected"
        case "中型犬":
            return selectedSizeCategory == "中型犬" ? "middledogselected" : "middledogunselected"
        case "大型犬":
            return selectedSizeCategory == "大型犬" ? "bigdogselected" : "bigdogunselected"
        default:
            return "smalldogunselected"
        }
    }
    
    // MARK: - ドッグフードカード
    // ドッグフードカード（変更）
    private func dogFoodCard(_ dogFood: DogFood,
                             averageRating: Double,
                             matchedID: String,
                             rank: Int,
                             onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DogFoodImageView(
                imagePath: dogFood.imagePath,
                storagePath: dogFood.storagePath,
                matchedID: matchedID,
                namespace: namespace,
                enableMatchedGeometry: false,
                reloadKey: imageReloadKey,
                shouldRetry: failedFoodImagePaths.contains(dogFood.imagePath),
                onLoadResult: { success in
                    if success {
                        failedFoodImagePaths.remove(dogFood.imagePath)
                    } else {
                        failedFoodImagePaths.insert(dogFood.imagePath)
                    }
                }
            )
            .overlay(alignment: .topLeading) {
                RankBadge(rank: rank)
                    .padding(6)
                    .allowsHitTesting(false)
            }
            
            if !dogFood.brandNonEmpty.isEmpty {
                Text(dogFood.brandNonEmpty)
                    .font(.caption2)
                    .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
                    .lineLimit(1)
                    .padding(.leading, 8)
            }
            Text(dogFood.name)
                .font(.caption)
                .lineLimit(2)                          // 最大2行まで表示
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity,
                       minHeight: 32,                  // 1行でも2行分の高さを確保して段ズレ防止
                       alignment: .topLeading)
                .padding(.leading, 8)
            
            // ★ 評価(平均) + 件数 + ハート
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", averageRating))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "ellipsis.message")
                    let cnt = foodVM.evaluationCount(for: dogFood.id)
                    Text("\(cnt.map(String.init) ?? "—")")
                        .redacted(reason: cnt == nil ? .placeholder : [])
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    if let id = dogFood.id {
                        Analytics.logEvent("favorite_toggle", parameters: [
                            "food_id": id,
                            "is_favorite": !foodVM.isFavorite(dogFood.id),
                            "from_screen": "ranking",
                            "size_category": selectedSizeCategory ?? "all",
                            "rank": rank
                        ])
                        foodVM.toggleFavorite(dogFoodID: id) // SSOT想定
                    }
                } label: {
                    Image(systemName: foodVM.isFavorite(dogFood.id) ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)   // 星の左に少しスペース
            .padding(.trailing, 8)  // ハートの右に少しスペース
        }
        .contentShape(Rectangle())     // セル全体をタップ可能に
        .onTapGesture { onTap() }      // 詳細へ遷移
        .onAppear {
            foodVM.loadEvaluationCountIfNeeded(for: dogFood.id) // 件数を取得（キャッシュ）
        }
        .task(id: evaluationCountReloadKey) {
            if let id = dogFood.id {
                foodVM.loadEvaluationCountIfNeeded(for: id)
            }
        }
    }
    
    
    // MARK: - タイトル
    private func rankingTitle() -> String {
        if let selected = selectedSizeCategory {
            return "\(selected)ランキング"
        } else {
            return "総合ランキング"
        }
    }

    @MainActor
    private func refreshRankingLight() async {
        // 画像：pull-to-refresh時のみ、失敗扱いの画像だけ再試行されるようにキーを更新
        imageReloadKey = UUID()

        // 表示対象のIDだけ件数キャッシュをリセットして取り直す
        let ids = rankedFoodIDs
        guard !ids.isEmpty else { return }
        foodVM.resetEvaluationCountCache(only: ids)
        ids.forEach { id in
            foodVM.loadEvaluationCountIfNeeded(for: id)
        }

        // セルを作り直さずに件数表示を再評価
        evaluationCountReloadKey = UUID()

        // ランキング本体も軽く最新化（既存ロジックに合わせる）
        rankingVM.refresh(sizeCategory: selectedSizeCategory)
    }
}

// MARK: -
// 左上の順位リボン（追加）
private struct RankBadge: View {
    let rank: Int
    var body: some View {
        VStack(spacing: 0) {
            Text("\(rank)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            
            // リボンの三角しっぽ
            Triangle()
                .fill(color)
                .frame(width: 16, height: 6)
        }
        .shadow(radius: 1, y: 1)
    }
    
    private var color: Color {
        switch rank {
        case 1: return .yellow   // お好みで色を調整
        case 2: return .gray
        case 3: return .brown
        default: return Color.gray.opacity(0.4)
        }
    }
}

// 三角形シェイプ（追加）
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width/2, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// --- 成分フィルターサマリー & わんちゃん選択バー（from SearchResultsView） ---
private struct ActiveFilterSummaryView: View {
    let include: Set<IngredientFilter>
    let exclude: Set<IngredientFilter>

    let foodType: FoodTypeFilter
    let caloriesFilter: NumericFilter
    let proteinFilter: NumericFilter
    let fatFilter: NumericFilter
    let fiberFilter: NumericFilter
    let ashFilter: NumericFilter
    let moistureFilter: NumericFilter

    private func formatValue(_ value: Double, step: Double) -> String {
        if step >= 1 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    private func numericSummary(title: String, unit: String, step: Double, filter: NumericFilter) -> String? {
        guard filter.isEnabled else { return nil }
        let minV = filter.minValue
        let maxV = filter.maxValue
        guard minV != nil || maxV != nil else { return nil }

        if let minV, let maxV {
            let lo = formatValue(minV, step: step)
            let hi = formatValue(maxV, step: step)
            return "\(title)：\(lo)〜\(hi)\(unit)"
        } else if let minV {
            let lo = formatValue(minV, step: step)
            return "\(title)：\(lo)\(unit)以上"
        } else if let maxV {
            let hi = formatValue(maxV, step: step)
            return "\(title)：\(hi)\(unit)以下"
        } else {
            return nil
        }
    }

    private var summaryText: String {
        var parts: [String] = []

        // フード種類
        if foodType != .all {
            parts.append("フード：\(foodType.label)")
        }

        // 成分（レンジ）
        if let s = numericSummary(title: "代謝エネルギー", unit: "kcal/100g", step: 1, filter: caloriesFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)タンパク質", unit: "%", step: 0.5, filter: proteinFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)脂質", unit: "%", step: 0.1, filter: fatFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)繊維", unit: "%", step: 0.1, filter: fiberFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)灰分", unit: "%", step: 0.1, filter: ashFilter) { parts.append(s) }
        if let s = numericSummary(title: "水分", unit: "%", step: 0.1, filter: moistureFilter) { parts.append(s) }

        // 成分（含む/含まない）
        let includeTexts = include
            .sorted { $0.displayName < $1.displayName }
            .map { "\($0.displayName)：含む" }

        let excludeTexts = exclude
            .sorted { $0.displayName < $1.displayName }
            .map { "\($0.displayName)：含まない" }

        parts.append(contentsOf: includeTexts)
        parts.append(contentsOf: excludeTexts)

        return parts.joined(separator: "　")
    }

    var body: some View {
        let hasNutrients =
            caloriesFilter.isEnabled
            || proteinFilter.isEnabled
            || fatFilter.isEnabled
            || fiberFilter.isEnabled
            || ashFilter.isEnabled
            || moistureFilter.isEnabled

        if foodType != .all || hasNutrients || !include.isEmpty || !exclude.isEmpty {
            Text(summaryText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DogSelectorBar: View {
    let dogs: [DogProfile]
    @Binding var selectedDogID: String?
    let isFiltering: Bool
    let onTapFilter: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("わんちゃんを選択(アレルギーで絞り込み)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dogs) { dog in
                            let isSelected = dog.id == selectedDogID

                            Button {
                                if isSelected {
                                    selectedDogID = nil
                                } else {
                                    selectedDogID = dog.id
                                }
                            } label: {
                                Text(dog.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color(red: 184/255, green: 164/255, blue: 144/255).opacity(0.4) : Color(.systemGray6))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color(red: 184/255, green: 164/255, blue: 144/255) : Color(.systemGray3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }

            Spacer()

            Button(action: onTapFilter) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: isFiltering ? .semibold : .regular))
                        .foregroundColor(isFiltering ? .black : .gray)

                    Text("フィルター")
                        .font(.system(size: 16, weight: isFiltering ? .semibold : .regular))
                        .foregroundColor(isFiltering ? .black : .gray)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("フィルター")
            .padding(.trailing, 8)
        }
        // (no .padding(.horizontal) here, to match SearchResultsView)
    }
}


struct RankingView_Previews: PreviewProvider {
    static var previews: some View {
        RankingView(useMockData: true)
            .environmentObject(DogFoodViewModel())
            .environmentObject(DogProfileViewModel())
    }
}
