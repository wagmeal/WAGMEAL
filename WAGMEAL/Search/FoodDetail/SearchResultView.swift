import SwiftUI
import FirebaseAnalytics

// MARK: - Extensions

extension DogFood {
    /// 詳細遷移やmatchedGeometryEffect用の安定ID
    var stableID: String { id ?? imagePath }
}

extension IngredientFilter {
    /// 画面表示用の日本語ラベル
    var displayName: String {
        switch self {
        case .chicken: return "鶏肉"
        case .beef: return "牛肉"
        case .pork: return "豚肉"
        case .lamb: return "羊肉"
        case .fish: return "魚"
        case .egg: return "卵"
        case .dairy: return "乳"
        case .wheat: return "小麦"
        case .corn: return "とうもろこし"
        case .soy: return "大豆"
        }
    }
}

private struct ActiveFilterSummaryView: View {
    let include: Set<IngredientFilter>
    let exclude: Set<IngredientFilter>

    let foodTypeFilter: FoodTypeFilter

    let caloriesFilter: NumericFilter
    let proteinFilter: NumericFilter
    let fatFilter: NumericFilter
    let fiberFilter: NumericFilter
    let ashFilter: NumericFilter
    let moistureFilter: NumericFilter

    private func formatValue(_ value: Double, step: Double) -> String {
        if step >= 1 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func numericSummary(title: String, unit: String, step: Double, filter: NumericFilter) -> String? {
        // 未適用なら表示しない
        guard filter.isEnabled else { return nil }

        let minV = filter.minValue
        let maxV = filter.maxValue
        // 念のため（isEnabledなのに両方nilのケース）
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
        if foodTypeFilter != .all {
            parts.append("種類：\(foodTypeFilter.label)")
        }

        // 成分値（適用中のみ表示）
        if let s = numericSummary(title: "代謝エネルギー", unit: "kcal/100g", step: 1, filter: caloriesFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)タンパク質", unit: "%", step: 0.5, filter: proteinFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)脂質", unit: "%", step: 0.1, filter: fatFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)繊維", unit: "%", step: 0.1, filter: fiberFilter) { parts.append(s) }
        if let s = numericSummary(title: "(粗)灰分", unit: "%", step: 0.1, filter: ashFilter) { parts.append(s) }
        if let s = numericSummary(title: "水分", unit: "%", step: 0.1, filter: moistureFilter) { parts.append(s) }

        // 成分（含む/含まない）
        let includeTexts = include.sorted { $0.displayName < $1.displayName }.map { "\($0.displayName)：含む" }
        let excludeTexts = exclude.sorted { $0.displayName < $1.displayName }.map { "\($0.displayName)：含まない" }

        parts.append(contentsOf: includeTexts)
        parts.append(contentsOf: excludeTexts)

        return parts.joined(separator: "　")
    }

    var body: some View {
        let hasFoodType = (foodTypeFilter != .all)
        let hasNutrients =
            caloriesFilter.isEnabled
            || proteinFilter.isEnabled
            || fatFilter.isEnabled
            || fiberFilter.isEnabled
            || ashFilter.isEnabled
            || moistureFilter.isEnabled

        if hasFoodType || hasNutrients || !include.isEmpty || !exclude.isEmpty {
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

// MARK: - SearchResultsView

struct SearchResultsView: View {
    @ObservedObject var viewModel: DogFoodViewModel
    @Binding var selectedDogIDs: Set<String>
    let dogs: [DogProfile]

    @Namespace private var namespace
    @State private var selectedDogFood: DogFood? = nil
    @State private var selectedMatchedID: String? = nil   // アニメ用に安定ID保持
    @State private var showDetail = false
    @FocusState private var isSearchFocused: Bool
    @State private var isShowingFilter = false
    @State private var isEditingFilters = false
    @State private var failedFoodImagePaths: Set<String> = []
    @State private var failedBrandImagePaths: Set<String> = []
    @State private var imageReloadKey = UUID()
    @State private var evaluationCountReloadKey = UUID() // 評価件数の再ロード用（セルを作り直さない）

    private var selectedDogs: [DogProfile] {
        dogs.filter { dog in
            if let id = dog.id {
                return selectedDogIDs.contains(id)
            }
            return false
        }
    }

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var trimmedSearchText: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        let hasDog = !selectedDogIDs.isEmpty
        let hasInclude = !viewModel.includeIngredientFilters.isEmpty
        let hasExclude = !viewModel.selectedIngredientFilters.isEmpty
        let hasFoodType = (viewModel.foodTypeFilter != .all)
        let hasNutrients =
            viewModel.caloriesFilter.isEnabled
            || viewModel.proteinFilter.isEnabled
            || viewModel.fatFilter.isEnabled
            || viewModel.fiberFilter.isEnabled
            || viewModel.ashFilter.isEnabled
            || viewModel.moistureFilter.isEnabled

        return hasDog || hasInclude || hasExclude || hasFoodType || hasNutrients
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SearchBarView(
                    searchText: $viewModel.searchText,
                    isSearchActive: $viewModel.isSearchActive,
                    isFocused: $isSearchFocused
                )
                .padding(.top, 6)

                DogSelectorBar(
                    dogs: dogs,
                    selectedDogIDs: $selectedDogIDs,
                    isFiltering: isFiltering,
                    onTapFilter: { isShowingFilter = true }
                )
                .padding(.top, 4)

                ActiveFilterSummaryView(
                    include: viewModel.includeIngredientFilters,
                    exclude: viewModel.selectedIngredientFilters,
                    foodTypeFilter: viewModel.foodTypeFilter,
                    caloriesFilter: viewModel.caloriesFilter,
                    proteinFilter: viewModel.proteinFilter,
                    fatFilter: viewModel.fatFilter,
                    fiberFilter: viewModel.fiberFilter,
                    ashFilter: viewModel.ashFilter,
                    moistureFilter: viewModel.moistureFilter
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear
                            .frame(height: 0)
                            .id("top")

                        resultsBody(proxy: proxy)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                let isRightSwipe =
                                    value.translation.width > 90 &&
                                    abs(value.translation.width) > abs(value.translation.height) * 1.5

                                let isListState =
                                    !trimmedSearchText.isEmpty ||
                                    viewModel.showAllFoodsFromBrandExplorer

                                guard isRightSwipe, isListState, !showDetail else { return }

                                withAnimation(.spring()) {
                                    viewModel.searchText = ""
                                    viewModel.isSearchActive = false
                                    viewModel.showAllFoodsFromBrandExplorer = false
                                    isSearchFocused = false
                                    hideKeyboard()
                                }

                                withAnimation {
                                    proxy.scrollTo("top", anchor: .top)
                                }
                            }
                    )
                    .refreshable {
                        imageReloadKey = UUID()

                        let ids = viewModel.filteredDogFoods.compactMap { $0.id }.filter { !$0.isEmpty }
                        if !ids.isEmpty {
                            viewModel.resetEvaluationCountCache(only: ids)
                            ids.forEach { id in
                                viewModel.loadEvaluationCountIfNeeded(for: id)
                            }
                        }

                        evaluationCountReloadKey = UUID()
                        viewModel.fetchDogFoods()
                    }
                }
            }
            .onAppear {
                Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                    AnalyticsParameterScreenName: "search_results",
                    AnalyticsParameterScreenClass: "SearchResultsView"
                ])
                applyAllergyFilters(for: selectedDogs)

                if let food = viewModel.selectedDogFood {
                    hideKeyboard()
                    isSearchFocused = false
                    withAnimation(.spring()) {
                        selectedDogFood = food
                        selectedMatchedID = food.stableID
                        showDetail = true
                    }
                    viewModel.selectedDogFood = nil
                }
            }
            .onChange(of: viewModel.isSearchActive) { active in
                if !active {
                    viewModel.showAllFoodsFromBrandExplorer = false
                }
            }
            .onChange(of: viewModel.selectedDogFood) { food in
                guard let food else { return }
                hideKeyboard()
                isSearchFocused = false
                withAnimation(.spring()) {
                    selectedDogFood = food
                    selectedMatchedID = food.stableID
                    showDetail = true
                }
                viewModel.selectedDogFood = nil
            }
            .onChange(of: selectedDogIDs) { _ in
                guard !isEditingFilters else { return }
                applyAllergyFilters(for: selectedDogs)
            }
            .onChange(of: trimmedSearchText) { newValue in
                guard !newValue.isEmpty else { return }
                Analytics.logEvent("search", parameters: [
                    "query_length": newValue.count,
                    "has_brand_filter": viewModel.showAllFoodsFromBrandExplorer,
                    "has_allergy_filter": !viewModel.selectedIngredientFilters.isEmpty
                ])
            }
            .sheet(isPresented: $isShowingFilter) {
                FilterSheetView(
                    include: $viewModel.includeIngredientFilters,
                    exclude: $viewModel.selectedIngredientFilters,
                    foodTypeFilter: $viewModel.foodTypeFilter,
                    caloriesFilter: $viewModel.caloriesFilter,
                    proteinFilter: $viewModel.proteinFilter,
                    fatFilter: $viewModel.fatFilter,
                    fiberFilter: $viewModel.fiberFilter,
                    ashFilter: $viewModel.ashFilter,
                    moistureFilter: $viewModel.moistureFilter,
                    selectedDog: selectedDogs.first,
                    onUseDogAllergy: { dog in
                        viewModel.selectedIngredientFilters = dog.allergyFilters
                        viewModel.includeIngredientFilters.removeAll()
                    }
                )
                .onAppear { isEditingFilters = true }
                .onDisappear { isEditingFilters = false }
            }

            if let dogFood = selectedDogFood, showDetail {
                DogFoodDetailView(
                    dogFood: dogFood,
                    dogs: dogs,
                    namespace: namespace,
                    matchedID: selectedMatchedID ?? (dogFood.id ?? "search-\(dogFood.imagePath)"),
                    isPresented: $showDetail
                )
                .id(selectedMatchedID ?? (dogFood.id ?? "search-\(dogFood.imagePath)"))
                .environmentObject(viewModel)
                .zIndex(1)
                .transition(.move(edge: .trailing))
                .gesture(
                    DragGesture().onEnded { value in
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
    }

    // MARK: - Scroll content

    @ViewBuilder
    private func resultsBody(proxy: ScrollViewProxy) -> some View {
        if !trimmedSearchText.isEmpty {
            gridSection(items: sortedForList(viewModel.filteredDogFoods))
        } else if viewModel.showAllFoodsFromBrandExplorer {
            gridSection(items: sortedForList(viewModel.filteredDogFoods))
        } else if isSearchFocused {
            gridSection(items: sortedForList(viewModel.filteredDogFoods))
        } else {
            brandExplorerSection(proxy: proxy)
        }
    }

    // ✅ ここが重要：評価件数を「一覧単位で」まとめてプリフェッチ
    private func gridSection(items: [DogFood]) -> AnyView {
        let ids = items.compactMap { $0.id }.filter { !$0.isEmpty }

        return AnyView(
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.stableID) { dogFood in
                    let matchedID = dogFood.stableID
                    dogFoodCard(dogFood, matchedID: matchedID, imageReloadKey: imageReloadKey) {
                        hideKeyboard()
                        isSearchFocused = false
                        withAnimation(.spring()) {
                            selectedDogFood = dogFood
                            selectedMatchedID = matchedID
                            showDetail = true
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .onAppear {
                guard !ids.isEmpty else { return }
                ids.forEach { id in
                    viewModel.loadEvaluationCountIfNeeded(for: id)
                }
            }
            .task(id: evaluationCountReloadKey) {
                guard !ids.isEmpty else { return }
                ids.forEach { id in
                    viewModel.loadEvaluationCountIfNeeded(for: id)
                }
            }
        )
    }

    private func brandExplorerSection(proxy: ScrollViewProxy) -> AnyView {
        let filteredFoods = viewModel.filteredDogFoods

        let brandCounts: [String: Int] = {
            let brands = filteredFoods.compactMap { food -> String? in
                let brand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return brand.isEmpty ? nil : brand
            }
            let grouped = Dictionary(grouping: brands, by: { $0 })
            return grouped.mapValues { $0.count }
        }()

        let brands = brandCounts.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return AnyView(
            BrandExplorerView(
                brands: brands,
                counts: brandCounts,
                totalCount: filteredFoods.count,
                imageReloadKey: imageReloadKey,
                imageProvider: { brand in
                    let target = filteredFoods.first {
                        ($0.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") == brand &&
                        (!($0.storagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         !$0.imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    return (imagePath: target?.imagePath, storagePath: target?.storagePath)
                },
                onTapAll: {
                    withAnimation(.spring()) {
                        viewModel.searchText = ""
                        viewModel.showAllFoodsFromBrandExplorer = true
                        viewModel.isSearchActive = false
                        isSearchFocused = false
                        hideKeyboard()
                    }
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                },
                onTap: { brand in
                    withAnimation(.spring()) {
                        viewModel.showAllFoodsFromBrandExplorer = false
                        viewModel.search(byBrand: brand)
                        viewModel.isSearchActive = false
                        isSearchFocused = false
                        hideKeyboard()
                    }
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        )
    }

    private func sortedForList(_ foods: [DogFood]) -> [DogFood] {
        foods.sorted { a, b in
            let aHasImage = !a.imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let bHasImage = !b.imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if aHasImage != bHasImage {
                return aHasImage && !bHasImage
            }

            let nameOrder = a.name.localizedCaseInsensitiveCompare(b.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return a.stableID.localizedCaseInsensitiveCompare(b.stableID) == .orderedAscending
        }
    }

    private func applyAllergyFilters(for dogs: [DogProfile]) {
        guard !dogs.isEmpty else {
            viewModel.selectedIngredientFilters = []
            return
        }

        var forbidden = Set<IngredientFilter>()
        for dog in dogs {
            forbidden.formUnion(dog.allergyFilters)
        }

        viewModel.selectedIngredientFilters = forbidden
        viewModel.includeIngredientFilters.removeAll()
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

    // MARK: - Card

    private func dogFoodCard(
        _ dogFood: DogFood,
        matchedID: String,
        imageReloadKey: UUID,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
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

            VStack(alignment: .leading, spacing: 6) {
                if !dogFood.brandNonEmpty.isEmpty {
                    Text(dogFood.brandNonEmpty)
                        .font(.caption2)
                        .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
                        .lineLimit(1)
                        .padding(.leading, 8)
                }

                Text(dogFood.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                    .padding(.leading, 8)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.message")
                        let count = viewModel.evaluationCount(for: dogFood.id)
                        Text(count.map(String.init) ?? "—")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        if let id = dogFood.id { viewModel.toggleFavorite(dogFoodID: id) }
                    } label: {
                        Image(systemName: viewModel.isFavorite(dogFood.id) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Analytics.logEvent("food_view", parameters: [
                "food_id": dogFood.id ?? "",
                "from_screen": "search_results"
            ])
            onTap()
        }
        // ✅ ここで loadEvaluationCountIfNeeded は呼ばない（上スクロールの連発を防ぐ）
    }
}



private struct DogSelectorBar: View {
    let dogs: [DogProfile]
    @Binding var selectedDogIDs: Set<String>
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
                            let isSelected = dog.id != nil && selectedDogIDs.contains(dog.id!)

                            Button {
                                guard let id = dog.id else { return }
                                if isSelected {
                                    selectedDogIDs.remove(id)
                                } else {
                                    selectedDogIDs.insert(id)
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
    }
}




// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @State private var selectedDogIDs: Set<String> = []

        var body: some View {
            let mockViewModel = DogFoodViewModel(mockData: true)
            // ブランドがモック内に無ければ、ブランド一覧は空のまま表示されます。
            mockViewModel.searchText = ""
            mockViewModel.isSearchActive = true

            return SearchResultsView(
                viewModel: mockViewModel,
                selectedDogIDs: $selectedDogIDs,
                dogs: PreviewMockData.dogs
            )
        }
    }

    return Wrapper()
}


